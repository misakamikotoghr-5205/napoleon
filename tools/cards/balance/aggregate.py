#!/usr/bin/env python3
"""Aggregate independent Godot runs using only the Python standard library."""
import argparse
import json
from pathlib import Path

METRICS = ('pass_rate', 'game_over_reasons', 'month_money', 'rep_tiers', 'heat_tiers',
           'demands', 'mortgaged', 'street', 'prison', 'big_fate', 'fate', 'hand_counts',
           'slot_checks', 'lot_accuracy', 'almanac', 'steps', 'stock')


def add_counts(target, source):
    for key, value in source.items():
        if isinstance(value, dict):
            add_counts(target.setdefault(key, {}), value)
        elif isinstance(value, (int, float)):
            target[key] = target.get(key, 0) + value


def quantiles(values):
    values = sorted(values)
    return {name: values[(len(values) - 1) * pct // 100] if values else None
            for name, pct in [('p10', 10), ('median', 50), ('p90', 90)]}


def stock_rates(stock):
    """Rogue v1 (RG6): share of weekly stocktakes that offered the full three; null when no weekly offer was seen."""
    weeks = stock.get('week_offers', 0)
    stock['week_full_rate'] = stock.get('week_sizes', {}).get('3', 0) / weeks if weeks else None
    return stock


def aggregate(runs):
    grouped = {}
    for run in runs:
        if run['policy'] == 'fuzz':
            continue
        for stage in range(max(run.get('stages_requested', 3), len(run['stages']))):
            row = run['stages'].get(str(stage), {'cleared': False, 'mortgaged': 0, 'steps': 0})
            grouped.setdefault((run['policy'], str(stage)), []).append(row)
    policies = {}
    for (policy, stage), rows in sorted(grouped.items()):
        metrics = {key: {} for key in METRICS}
        metrics['pass_rate'] = {'cleared': sum(bool(row['cleared']) for row in rows), 'runs': len(rows)}
        metrics['pass_rate']['rate'] = metrics['pass_rate']['cleared'] / len(rows)
        reached = sum(bool(row.get('reached', row.get('steps', 0) > 0)) for row in rows)
        metrics['pass_rate']['reached'] = reached
        metrics['pass_rate']['conditional_rate'] = metrics['pass_rate']['cleared'] / reached if reached else None
        metrics['month_money'] = quantiles([row['month_money'] for row in rows if 'month_money' in row])
        metrics['month_money']['samples'] = sum('month_money' in row for row in rows)
        metrics['mortgaged'] = quantiles([row['mortgaged'] for row in rows])
        metrics['steps'] = quantiles([row['steps'] for row in rows])
        for key in METRICS:
            if key not in ['pass_rate', 'month_money', 'mortgaged', 'steps']:
                for row in rows:
                    add_counts(metrics[key], row.get(key, {}))
        street = metrics['street']
        street['entered_runs'] = sum(bool(row.get('street', {}).get('entered', 0)) for row in rows)
        street['rate'] = street['entered_runs'] / len(rows)
        street['affected_runs'] = sum(bool(row.get('street', {}).get('entered', 0)
                                          or row.get('street', {}).get('days', 0)) for row in rows)
        street['affected_rate'] = street['affected_runs'] / len(rows)
        street['recovery_rate'] = street.get('recovered', 0) / street['entered'] if street.get('entered', 0) else None
        prison = metrics['prison']
        prison['release_rate'] = prison.get('released', 0) / prison['arrests'] if prison.get('arrests', 0) else None
        for check in metrics['slot_checks'].values():
            check['rate'] = check['success'] / check['total'] if check.get('total', 0) else None
        fate = metrics['fate']
        fate_total = sum(fate.values())
        fate['good_rate'] = fate.get('good', 0) / fate_total if fate_total else None
        fate['bad_rate'] = fate.get('bad', 0) / fate_total if fate_total else None
        lot = metrics['lot_accuracy']
        lot['rate'] = lot.get('correct', 0) / lot['verified'] if lot.get('verified', 0) else None
        alm = metrics['almanac']
        alm['rate'] = alm.get('followed', 0) / alm['offered'] if alm.get('offered', 0) else None
        stock_rates(metrics['stock'])
        policies.setdefault(policy, {})[stage] = metrics
    return {'schema': 1, 'runs': len(runs), 'policies': policies,
            'notes': ['Rates with no observations are null; they are not claims of success.',
                      'Applied numeric overrides and engine/data provenance are recorded in inputs.',
                      'Public runtime lot accuracy is unavailable: hidden predictions are excluded by contract 9.3 (issue #41).'],
            'external_lot_certificate': {'status': 'not_loaded'}}


def stock_table(policies):
    """Rogue v1 (RG6): the stocktake table; omitted when no policy saw any offer (rogue modules off or no data)."""
    rows = [(policy, stage, row.get('stock', {})) for policy, stages in policies.items() for stage, row in stages.items()]
    if not any(stock.get('offers', 0) for _policy, _stage, stock in rows):
        return []
    lines = ['', '| Policy | Stage | Week offers (3 items) | Peddler offers | Picked relic / source | Passed | Replaced | '
             'Rejected | Deals per stocktake week |', '|---|---:|---:|---:|---:|---:|---:|---:|---:|']
    for policy, stage, stock in rows:
        weeks = stock.get('week_offers', 0)
        kinds = stock.get('picked_kinds', {})
        deals = stock.get('week_deals', {})
        lines.append(f"| {policy} | {stage} | {weeks} ({stock.get('week_sizes', {}).get('3', 0)}) | "
                     f"{stock.get('peddler_offers', 0)} | {kinds.get('relic', 0)} / {kinds.get('source', 0)} | "
                     f"{stock.get('passed', 0)} | {stock.get('replaced', 0)} | {stock.get('rejected', 0)} | "
                     + ' / '.join(str(deals.get(str(week), 0)) for week in range(4)) + ' |')
    return lines


# ---------------- Rogue v1 A/B (RG6; docs/cards/rogue/ROGUE_V1.md §14 RG6 phase 2) ----------------
AB_STAGES = ('0', '1', '2')


def _cell(report, policy, stage):
    row = report['policies'].get(policy, {}).get(stage)
    if row is None:
        return {'cleared': None, 'runs': 0, 'median': None, 'samples': 0}
    return {'cleared': row['pass_rate']['cleared'], 'runs': row['pass_rate']['runs'],
            'median': row['month_money']['median'], 'samples': row['month_money']['samples']}


def _sub(a, b):
    return None if a is None or b is None else a - b


def _stock_sum(report, policy, field):
    total = {}
    for stage in report['policies'].get(policy, {}).values():
        add_counts(total, {'x': stage.get('stock', {}).get(field, {})})
    return total.get('x', {})


def _week_full(report, policy):
    weeks = sum(row.get('stock', {}).get('week_offers', 0) for row in report['policies'].get(policy, {}).values())
    full = sum(row.get('stock', {}).get('week_sizes', {}).get('3', 0)
               for row in report['policies'].get(policy, {}).values())
    return {'full': full, 'weeks': weeks, 'rate': full / weeks if weeks else None}


def rogue_catalog(data_root):
    """Relic and source ids of one data root (any era file with cards of type relic / source)."""
    ids = {'relic': set(), 'source': set()}
    for path in sorted(Path(data_root).glob('era/**/*.json')):
        document = json.loads(path.read_text())
        for card in document.get('cards', []) if isinstance(document, dict) else []:
            if isinstance(card, dict) and card.get('type') in ids:
                ids[card['type']].add(card['id'])
    return {kind: sorted(values) for kind, values in ids.items()}


def ab_compare(on, off, catalog):
    """A1-A7 of ROGUE_V1.md §14 RG6 from two aggregate reports (on = rogue modules enabled, off = disabled).
    Clears are per stage out of all seeds; month cash medians only count runs that finished that month."""
    cells = {side: {policy: {stage: _cell(report, policy, stage) for stage in AB_STAGES}
                    for policy in sorted(report['policies'])} for side, report in (('on', on), ('off', off))}

    def get(side, policy, stage, key):
        return cells[side].get(policy, {}).get(stage, {}).get(key)

    def gain(policy, stage):
        return _sub(get('on', policy, stage, 'median'), get('off', policy, stage, 'median'))

    checks = {}
    a1 = []
    for stage in AB_STAGES:
        on_c, off_c = get('on', 'refuser', stage, 'cleared'), get('off', 'refuser', stage, 'cleared')
        on_m, off_m = get('on', 'refuser', stage, 'median'), get('off', 'refuser', stage, 'median')
        a1.append(on_c is not None and off_c is not None and abs(on_c - off_c) <= 1)
        a1.append(on_m is not None and off_m is not None and abs(on_m - off_m) * 100 <= 5 * abs(off_m))
    checks['A1'] = {'pass': all(a1), 'rule': 'refuser on/off: clears differ <= 1 and month cash medians differ <= 5% '
                                            'in each of the three stages'}
    a2 = [get('on', 'trader', stage, 'cleared') is not None and get('off', 'trader', stage, 'cleared') is not None
          and get('on', 'trader', stage, 'cleared') >= get('off', 'trader', stage, 'cleared') for stage in AB_STAGES]
    for stage in ('1', '2'):
        on_m, off_m = get('on', 'trader', stage, 'median'), get('off', 'trader', stage, 'median')
        a2.append(on_m is not None and off_m is not None and on_m * 100 >= off_m * 110)
    checks['A2'] = {'pass': all(a2), 'rule': 'trader: on clears >= off clears in each stage; stage 2 and 3 month cash '
                                            'median on >= off x 1.10'}
    a3 = [get('on', 'fair', stage, 'cleared') is not None and get('off', 'fair', stage, 'cleared') is not None
          and get('on', 'fair', stage, 'cleared') >= get('off', 'fair', stage, 'cleared') - 1 for stage in AB_STAGES]
    checks['A3'] = {'pass': all(a3), 'rule': 'fair: on clears >= off clears - 1 in each stage'}
    gap_on = _sub(get('on', 'trader', '2', 'median'), get('on', 'refuser', '2', 'median'))
    gap_off = _sub(get('off', 'trader', '2', 'median'), get('off', 'refuser', '2', 'median'))
    checks['A4'] = {'pass': gap_on is not None and gap_off is not None and gap_on > gap_off,
                    'rule': 'stage 3 month cash median: (trader on - refuser on) > (trader off - refuser off)',
                    'gap_on': gap_on, 'gap_off': gap_off}
    idle_gain = [gain('idle', stage) for stage in AB_STAGES]
    trader_gain = [gain('trader', stage) for stage in AB_STAGES]
    idle_total = None if None in idle_gain else sum(idle_gain)
    trader_total = None if None in trader_gain else sum(trader_gain)
    checks['A5'] = {'pass': idle_total is not None and trader_total is not None and idle_total < trader_total,
                    'rule': 'sum over the three stages of the month cash median gain (on - off): idle < trader',
                    'idle_gain': idle_gain, 'trader_gain': trader_gain, 'idle_total': idle_total,
                    'trader_total': trader_total}
    trader_full, idle_full = _week_full(on, 'trader'), _week_full(on, 'idle')
    checks['A6'] = {'pass': trader_full['rate'] is not None and idle_full['rate'] is not None
                    and trader_full['full'] * 100 >= 60 * trader_full['weeks']
                    and idle_full['full'] * 100 <= 10 * idle_full['weeks'],
                    'rule': 'weekly stocktakes offering 3 items (on): trader >= 60%, idle <= 10%',
                    'trader': trader_full, 'idle': idle_full}
    offered, picked = {}, {}
    for policy in on['policies']:
        add_counts(offered, _stock_sum(on, policy, 'offered'))
    for policy in ('trader', 'random'):
        add_counts(picked, _stock_sum(on, policy, 'picked'))
    never_offered = [item for kind in ('relic', 'source') for item in catalog[kind] if not offered.get(item, 0)]
    never_picked = [item for item in catalog['relic'] if not picked.get(item, 0)]
    checks['A7'] = {'pass': bool(catalog['relic']) and bool(catalog['source']) and not never_offered and not never_picked,
                    'rule': 'every relic and source offered somewhere (on); trader or random picked every relic',
                    'relics': len(catalog['relic']), 'sources': len(catalog['source']),
                    'never_offered': never_offered, 'never_picked_by_trader_or_random': never_picked,
                    'random_ran': 'random' in on['policies'], 'offered': offered, 'picked_trader_random': picked}
    return {'schema': 1, 'cells': cells, 'checks': checks, 'db_hashes': {'on': on.get('db_hashes'),
                                                                         'off': off.get('db_hashes')}}


def ab_markdown(result, date):
    cells, checks = result['cells'], result['checks']
    lines = [f'# Rogue v1 A/B {date}', '', 'on = relics + stock enabled; off = both disabled by balance_overrides.json.',
             'Clears out of all seeds; cash = month-end cash median over runs that finished that month (n).', '',
             '| Policy | Stage | Clears on / off | Cash median on / off (n on / off) | Gain on - off |',
             '|---|---:|---:|---:|---:|']
    for policy in sorted(set(cells['on']) | set(cells['off'])):
        for stage in AB_STAGES:
            a, b = cells['on'].get(policy, {}).get(stage, {}), cells['off'].get(policy, {}).get(stage, {})
            lines.append(f"| {policy} | {stage} | {a.get('cleared')} / {b.get('cleared')} | {a.get('median')} / "
                         f"{b.get('median')} ({a.get('samples', 0)} / {b.get('samples', 0)}) | "
                         f"{_sub(a.get('median'), b.get('median'))} |")
    lines += ['', '| Check | Result | Rule | Numbers |', '|---|---|---|---|']
    for name, check in checks.items():
        numbers = {key: value for key, value in check.items() if key not in ('pass', 'rule', 'offered',
                                                                               'picked_trader_random')}
        lines.append(f"| {name} | {'PASS' if check['pass'] else 'FAIL'} | {check['rule']} | "
                     f"{json.dumps(numbers, ensure_ascii=False)} |")
    return lines + ['']


def ab_main(args):
    on = json.loads(Path(args.ab_on).read_text())
    off = json.loads(Path(args.ab_off).read_text())
    if on.get('db_hashes') == off.get('db_hashes'):
        raise ValueError('on and off reports share a database hash; the overrides did not reach one side')
    result = ab_compare(on, off, rogue_catalog(args.ab_data))
    result['date'] = args.date
    base = Path(args.out) / f'ab_{args.date}'
    base.with_suffix('.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    base.with_suffix('.md').write_text('\n'.join(ab_markdown(result, args.date)))
    print(base.with_suffix('.md'))
    for name, check in result['checks'].items():
        print(f"ROGUE AB {name} {'PASS' if check['pass'] else 'FAIL'}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', required=True)
    parser.add_argument('--date', required=True)
    parser.add_argument('--parts', action='append')
    parser.add_argument('--ab-on', help='Rogue v1: aggregate report JSON with relics/stock enabled')
    parser.add_argument('--ab-off', help='Rogue v1: aggregate report JSON with relics/stock disabled')
    parser.add_argument('--ab-data', help='Rogue v1: data root whose relic/source ids A7 must cover')
    args = parser.parse_args()
    if args.ab_on or args.ab_off:
        if not (args.ab_on and args.ab_off and args.ab_data):
            parser.error('--ab-on, --ab-off and --ab-data go together')
        ab_main(args)
        return
    out = Path(args.out)
    runs = []
    labels = set()
    db_hashes = set()
    source_revisions = set()
    inputs = []
    for folder in args.parts or [args.out]:
        for path in sorted(Path(folder).glob('runs_*.json')):
            document = json.loads(path.read_text())
            labels.add(document.get('dataset_label', document.get('data', 'unknown')))
            db_hashes.add(document.get('db_hash', 'not_recorded'))
            source_revisions.add(document.get('source_revision', 'not_recorded'))
            metadata = {key: value for key, value in document.items() if key != 'runs'}
            if metadata not in inputs:
                inputs.append(metadata)
            runs.extend(document['runs'])
    if not runs:
        raise ValueError('No runs found; refusing to report an empty simulation as success')
    identities = [(run['policy'], run['seed']) for run in runs]
    if len(identities) != len(set(identities)):
        raise ValueError('Duplicate policy/seed observations')
    if len(db_hashes) != 1:
        raise ValueError('Mixed databases; compare separate reports instead')
    report = aggregate(runs)
    report['date'] = args.date
    report['datasets'] = sorted(labels)
    report['db_hashes'] = sorted(db_hashes)
    report['source_revisions'] = sorted(source_revisions)
    report['inputs'] = inputs
    fuzz = [run for run in runs if run['policy'] == 'fuzz']
    report['fuzz'] = {
        'runs': len(fuzz), 'passed': sum(bool(run['result'].get('ok', False)) for run in fuzz),
        'stages_requested': sorted({run.get('stages_requested', 3) for run in fuzz}),
        'preview_checks': sum(run['result'].get('fuzz', {}).get('preview_checks', 0) for run in fuzz),
        'end_checks': sum(run['result'].get('fuzz', {}).get('end_checks', 0) for run in fuzz),
        'escape_checks': sum(run['result'].get('fuzz', {}).get('escape_checks', 0) for run in fuzz),
        'max_escape_steps': max((run['result'].get('fuzz', {}).get('max_escape_steps', 0) for run in fuzz), default=0),
        'save_loads': sum(run['result'].get('fuzz', {}).get('save_loads', 0) for run in fuzz),
        'fresh_facades': sum(run['result'].get('fuzz', {}).get('fresh_facades', 0) for run in fuzz),
        'expected_rejections': sum(run['result'].get('fuzz', {}).get('expected_rejections', 0) for run in fuzz),
        'failed_seeds': [run['seed'] for run in fuzz if not run['result'].get('ok', False)],
        'scope': 'Public API; three stages or legitimate game over; state integer checks and sampled replay belong to G06_no_deadlock suite.'}
    outcomes = {}
    for run in runs:
        row = outcomes.setdefault(run['policy'], {'runs': 0, 'ok': 0, 'reasons': {}})
        row['runs'] += 1
        row['ok'] += bool(run['result'].get('ok', False))
        reason = run['result'].get('game_over_reason') or 'requested_limit'
        row['reasons'][reason] = row['reasons'].get(reason, 0) + 1
    report['run_outcomes'] = outcomes
    repo = Path(__file__).resolve().parents[3]
    certificates = {}
    for evidence_path in sorted((repo / 'scripts/tests/cards/G05').glob('evidence*.json')):
        certificates[evidence_path.name] = {'source': str(evidence_path.relative_to(repo)),
                                           'evidence': json.loads(evidence_path.read_text())}
    report['external_lot_certificate'] = certificates or {'status': 'not_available'}
    base = out / f'report_{args.date}'
    base.with_suffix('.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    lines = [f'# G06 balance report {args.date}', '', f'Runs: {len(runs)}. Overrides: see JSON inputs.',
             'Dataset: ' + ', '.join(report['datasets']) + '.', '',
             '| Policy | Stage | Cleared / runs | Month cash median | Steps median | Lot accuracy |',
             '|---|---:|---:|---:|---:|---:|']
    for policy, stages in report['policies'].items():
        for stage, row in stages.items():
            passed = row['pass_rate']
            lines.append(f"| {policy} | {stage} | {passed['cleared']} / {passed['runs']} | "
                         f"{row['month_money']['median']} | {row['steps']['median']} | {row['lot_accuracy']['rate']} |")
    lines += stock_table(report['policies'])
    lines += ['', 'Full distributions, denominators and all contract metrics are in the adjacent JSON.',
              'Unobserved ratios are null. No claims are made about unobserved mechanisms.',
              'Lot certification is separate offline G05 evidence; it is not sampled by the public runtime API.',
              'Run completion reasons (including any stalls) are stored in run_outcomes.', '']
    if fuzz:
        lines += [f"打烊不卡死：{report['fuzz']['passed']}/{len(fuzz)}。",
                  'Fuzz runs finish after three stages or legitimate game over; terminal retry is checked separately.', '']
    base.with_suffix('.md').write_text('\n'.join(lines))
    print(base.with_suffix('.md'))
    failed = sum(not run['result'].get('ok', False) for run in runs)
    print(f'BALANCE RESULT passed={len(runs) - failed} failed={failed}')
    if failed:
        raise SystemExit(1)


if __name__ == '__main__':
    main()

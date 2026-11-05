"""G06：验证未到达关卡、真正月底和跨关街头的报告分母。"""
import unittest

from aggregate import aggregate, ab_compare, stock_table


class AggregateTests(unittest.TestCase):
    def test_censored_stage_and_cash_denominators(self):
        runs = [
            {'policy': 'fair', 'stages_requested': 3, 'stages': {
                '0': {'cleared': True, 'reached': True, 'month_money': 100, 'mortgaged': 1, 'steps': 10},
                '1': {'cleared': False, 'reached': True, 'mortgaged': 0, 'steps': 5,
                      'street': {'entered': 0, 'days': 5, 'recovered': 0}}}},
            {'policy': 'fair', 'stages_requested': 3, 'stages': {
                '0': {'cleared': False, 'reached': True, 'mortgaged': 2, 'steps': 7}}},
        ]
        rows = aggregate(runs)['policies']['fair']
        self.assertEqual(rows['0']['pass_rate']['rate'], 0.5)
        self.assertEqual(rows['0']['month_money']['samples'], 1)
        self.assertEqual(rows['0']['month_money']['median'], 100)
        self.assertEqual(rows['1']['pass_rate']['reached'], 1)
        self.assertEqual(rows['1']['street']['affected_runs'], 1)
        self.assertEqual(rows['1']['street']['entered_runs'], 0)
        self.assertEqual(rows['2']['pass_rate']['runs'], 2)
        self.assertIsNone(rows['2']['pass_rate']['conditional_rate'])
        self.assertIsNone(rows['2']['month_money']['median'])
        self.assertIsNone(rows['2']['lot_accuracy']['rate'])


    def test_rogue_stock_rates_and_ab_checks(self):
        """Rogue v1 (RG6): stock counters sum per policy/stage and A1-A7 read clears, cash medians and stock rows."""
        def run(policy, seed, side_cash, cleared=True, stock=None):
            stages = {}
            for stage, cash in enumerate(side_cash):
                row = {'cleared': cleared, 'reached': True, 'mortgaged': 0, 'steps': 1, 'month_money': cash}
                if stock and str(stage) in stock:
                    row['stock'] = stock[str(stage)]
                stages[str(stage)] = row
            return {'policy': policy, 'seed': seed, 'stages_requested': 3, 'stages': stages}

        full = {'offers': 2, 'week_offers': 2, 'week_sizes': {'3': 2}, 'offered': {'rl.a': 1, 'ky.b': 1},
                'picked': {'rl.a': 1}, 'picked_kinds': {'relic': 1, 'source': 0}}
        few = {'offers': 2, 'week_offers': 2, 'week_sizes': {'2': 2}, 'offered': {'rl.a': 1},
               'picked': {'rl.a': 1}, 'picked_kinds': {'relic': 1, 'source': 0}}
        on = aggregate([run('refuser', 1, [100, 100, 100], stock={'0': few}),
                        run('fair', 1, [100, 100, 100]),
                        run('trader', 1, [150, 150, 150], stock={'0': full}),
                        run('idle', 1, [100, 100, 100], stock={'0': few})])
        off = aggregate([run('refuser', 1, [100, 100, 100]), run('fair', 1, [100, 100, 100]),
                         run('trader', 1, [120, 120, 120]), run('idle', 1, [100, 100, 100])])
        self.assertEqual(on['policies']['trader']['0']['stock']['week_full_rate'], 1.0)
        self.assertEqual(on['policies']['idle']['0']['stock']['week_full_rate'], 0.0)
        self.assertIsNone(off['policies']['trader']['0']['stock']['week_full_rate'])
        self.assertTrue(any('rl.a' not in line and '| trader | 0 | 2 (2)' in line for line in stock_table(on['policies'])))
        self.assertEqual(stock_table(off['policies']), [])
        checks = ab_compare(on, off, {'relic': ['rl.a'], 'source': ['ky.b']})['checks']
        self.assertEqual({name: check['pass'] for name, check in checks.items()},
                         {'A1': True, 'A2': True, 'A3': True, 'A4': True, 'A5': True, 'A6': True, 'A7': True})
        self.assertEqual(checks['A4']['gap_on'], 50)
        self.assertEqual(checks['A4']['gap_off'], 20)
        self.assertEqual(checks['A5']['trader_total'], 90)
        self.assertEqual(checks['A6']['idle']['rate'], 0.0)
        self.assertEqual(checks['A6']['trader']['weeks'], 2)
        lucky_idle = aggregate([run('refuser', 1, [100, 100, 100]), run('fair', 1, [100, 100, 100]),
                                run('trader', 1, [150, 150, 150], stock={'0': full}),
                                run('idle', 1, [100, 100, 100], stock={'0': full})])
        self.assertFalse(ab_compare(lucky_idle, off, {'relic': ['rl.a'], 'source': ['ky.b']})['checks']['A6']['pass'])
        missing = ab_compare(on, off, {'relic': ['rl.a', 'rl.c'], 'source': ['ky.b']})['checks']['A7']
        self.assertFalse(missing['pass'])
        self.assertEqual(missing['never_offered'], ['rl.c'])
        self.assertEqual(missing['never_picked_by_trader_or_random'], ['rl.c'])


if __name__ == '__main__':
    unittest.main()

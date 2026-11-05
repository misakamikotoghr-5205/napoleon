const { chromium } = require('/opt/node-tools/node_modules/playwright');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage();
  await p.goto('file://' + process.cwd() + '/plan.html');
  await p.waitForTimeout(500);
  await p.pdf({ path: process.argv[2] || 'plan.pdf', format: 'A4', landscape: true, printBackground: true, preferCSSPageSize: true });
  await b.close();
})();

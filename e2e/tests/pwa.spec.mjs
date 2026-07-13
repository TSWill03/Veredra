import { test, expect } from '@playwright/test';
import { enableFlutterSemantics } from './helpers.mjs';

test('loads from /Veredra/, imports text and reopens after reload', async ({ page }) => {
  await page.goto('./');
  await expect(page).toHaveTitle('Veredra');
  await enableFlutterSemantics(page);

  await page.getByRole('button', { name: 'Importar livro' }).click();
  const chooserPromise = page.waitForEvent('filechooser');
  await page.getByText('Arquivos de texto').click();
  const chooser = await chooserPromise;
  await chooser.setFiles({
    name: 'e2e_capitulo.txt',
    mimeType: 'text/plain',
    buffer: Buffer.from('Capitulo E2E\n\nConteudo persistente Unicode: acao, cafe, 日本語.'),
  });

  await expect(
    page.getByRole('group', { name: /Conteudo persistente Unicode/ }),
  ).toBeVisible();
  await page.getByRole('button', { name: /^Back/ }).dispatchEvent('click');
  const importedBook = page.getByRole('group', {
    name: /^e2e_capitulo Texto - 1 capitulos/,
  });
  await expect(importedBook).toBeVisible();
  await page.reload();
  await enableFlutterSemantics(page);
  await expect(importedBook).toBeVisible();
});

test('installed PWA shell reloads offline under the case-sensitive subpath', async ({ page, context }) => {
  await page.goto('./');
  await enableFlutterSemantics(page);
  await page.evaluate(async () => {
    await navigator.serviceWorker.ready;
  });
  await page.waitForTimeout(1500);
  await context.setOffline(true);
  try {
    await page.reload({ waitUntil: 'domcontentloaded' });
    await expect(page).toHaveTitle('Veredra');
    await expect(page.locator('flutter-view')).toBeVisible();
  } finally {
    await context.setOffline(false);
  }
});

test('redirects /Veredra to the canonical trailing slash', async ({ page }) => {
  await page.goto('http://127.0.0.1:4173/Veredra');
  await expect(page).toHaveURL(/\/Veredra\/$/);
});

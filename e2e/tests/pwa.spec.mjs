import { test, expect } from '@playwright/test';
import { enableFlutterSemantics } from './helpers.mjs';

test('loads from /veredra/, imports text and reopens after reload', async ({ page }) => {
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

test('redirects /Veredra to the lowercase canonical route', async ({ page }) => {
  await page.goto('http://127.0.0.1:4173/Veredra');
  await expect(page).toHaveURL(/\/veredra\/$/);
});

test('persists a reader bookmark after reload', async ({ page }) => {
  await page.goto('./');
  await enableFlutterSemantics(page);

  await page.getByRole('button', { name: 'Importar livro' }).click();
  const chooserPromise = page.waitForEvent('filechooser');
  await page.getByText('Arquivos de texto').click();
  const chooser = await chooserPromise;
  await chooser.setFiles({
    name: 'e2e_marcador.txt',
    mimeType: 'text/plain',
    buffer: Buffer.from(
      'Capitulo Marcador E2E\n\nTrecho usado para validar marcador e persistencia local.',
    ),
  });

  await page.getByRole('button', { name: 'Novo marcador' }).click();
  await page.getByLabel('Trecho importante').fill('Trecho persistente E2E');
  await page.getByRole('button', { name: 'Salvar' }).click();
  await expect(page.getByText('Marcador salvo.').last()).toBeVisible();

  await page.getByRole('button', { name: /^Back/ }).dispatchEvent('click');
  await page.reload();
  await enableFlutterSemantics(page);
  const importedBook = page.getByRole('group', {
    name: /^e2e_marcador Texto - 1 capitulos/,
  });
  await expect(importedBook).toBeVisible();
  await importedBook.getByRole('button', { name: 'Abrir' }).click();

  await page.getByRole('button', { name: 'Capitulos e marcadores' }).click();
  await page.getByRole('tab', { name: 'Marcadores' }).click();
  await expect(
    page.getByRole('button', { name: /Trecho persistente E2E/ }),
  ).toBeVisible();
});

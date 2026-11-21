import { test, expect } from '@playwright/test';
import { strToU8, zipSync } from 'fflate';
import { enableFlutterSemantics } from './helpers.mjs';

test('imports chapter ZIP without overwriting earlier books and survives reload', async ({ page }) => {
  await page.goto('./');
  await enableFlutterSemantics(page);

  async function importArchive(text) {
    await page.getByRole('button', { name: 'Importar livro' }).click();
    const chooserPromise = page.waitForEvent('filechooser');
    await page.getByText('ZIP de capitulos').click();
    const chooser = await chooserPromise;
    await chooser.setFiles({
      name: 'zip_e2e_regression.zip',
      mimeType: 'application/zip',
      buffer: Buffer.from(zipSync({
        'Capitulos/1.txt': strToU8('Capitulo um: ' + text),
        'Capitulos/2.txt': strToU8('Capitulo dois: ' + text),
      })),
    });
    await page.getByRole('button', { name: /^Back/ }).dispatchEvent('click');
  }

  await importArchive('VERSAO ORIGINAL');
  await expect(page.getByRole('group', { name: /zip_e2e_regression Texto - 2 capitulos/ })).toHaveCount(1);

  // Same filename, count, and titles but different text must never mutate the first book.
  await importArchive('SEGUNDA VERSAO');
  await expect(page.getByRole('group', { name: /zip_e2e_regression Texto - 2 capitulos/ })).toHaveCount(2);

  await page.reload();
  await enableFlutterSemantics(page);
  const books = page.getByRole('group', { name: /zip_e2e_regression Texto - 2 capitulos/ });
  await expect(books).toHaveCount(2);
  // Inspect local storage directly rather than relying on Flutter's transient
  // accessibility-tree ordering. Both imported copies must remain untouched.
  const stored = await page.evaluate(async () => {
    const db = await new Promise((resolve, reject) => {
      const request = indexedDB.open('veredra_local_storage');
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    return await new Promise((resolve, reject) => {
      const entries = [];
      const tx = db.transaction('entries', 'readonly');
      const cursorRequest = tx.objectStore('entries').openCursor();
      cursorRequest.onsuccess = () => {
        const cursor = cursorRequest.result;
        if (!cursor) { db.close(); resolve(entries); return; }
        if (String(cursor.key).includes('imported_text_archives/')) {
          entries.push({ key: String(cursor.key), content: String(cursor.value?.value ?? cursor.value) });
        }
        cursor.continue();
      };
      cursorRequest.onerror = () => reject(cursorRequest.error);
    });
  });

  expect(stored.filter(({ content }) => content.includes('VERSAO ORIGINAL'))).toHaveLength(2);
  expect(stored.filter(({ content }) => content.includes('SEGUNDA VERSAO'))).toHaveLength(2);
  expect(new Set(stored.map(({ key }) => key.split('imported_text_archives/')[1].split('/')[0])).size).toBe(2);
});

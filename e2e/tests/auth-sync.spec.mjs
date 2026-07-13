import { test, expect } from '@playwright/test';
import { enableFlutterSemantics, openAccount, signIn } from './helpers.mjs';

const email = process.env.VEREDRA_E2E_EMAIL;
const password = process.env.VEREDRA_E2E_PASSWORD;

test.describe('configured Supabase authentication and sync', () => {
  test.skip(!email || !password, 'Requires dedicated Supabase E2E credentials.');

  test('login, metadata sync and recovery request', async ({ browser }) => {
    const firstContext = await browser.newContext();
    const first = await firstContext.newPage();
    await first.goto('http://127.0.0.1:4173/Veredra/');
    await enableFlutterSemantics(first);
    await signIn(first, email, password);

    await first.getByRole('switch', { name: 'Sincronizar dados de leitura' }).check();
    await first.getByRole('button', { name: 'Sincronizar agora' }).click();
    await expect(first.getByText('Sincronizado')).toBeVisible();
    await firstContext.close();

    const secondContext = await browser.newContext();
    const second = await secondContext.newPage();
    await second.goto('http://127.0.0.1:4173/Veredra/');
    await enableFlutterSemantics(second);
    await signIn(second, email, password);
    await expect(second.getByText('E-mail verificado')).toBeVisible();
    await secondContext.close();
  });

  test('password recovery exposes a neutral success message', async ({ page }) => {
    await page.goto('./');
    await enableFlutterSemantics(page);
    await openAccount(page);
    await page.getByLabel('E-mail').fill(email);
    await page.getByRole('button', { name: 'Esqueci minha senha' }).click();
    await expect(page.getByText(/Se o e-mail existir/)).toBeVisible();
  });
});

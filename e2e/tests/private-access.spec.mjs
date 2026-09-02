import { test, expect } from '@playwright/test';
import { enableFlutterSemantics } from './helpers.mjs';

test('@private private build exposes only login and password recovery entry', async ({ page }) => {
  await page.goto('./');
  await expect(page).toHaveTitle('Veredra');
  await enableFlutterSemantics(page);

  await expect(page.getByText('Veredra privado')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Entrar' })).toBeVisible();
  await expect(page.getByText('Esqueci minha senha')).toBeVisible();
  await expect(page.getByText('Criar conta')).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Importar livro' })).toHaveCount(0);
});

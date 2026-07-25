import { expect } from '@playwright/test';

export async function enableFlutterSemantics(page) {
  await expect
    .poll(() => page.locator('canvas').count())
    .toBeGreaterThan(0);
  const accessibilityButton = page.getByRole('button', {
    name: 'Enable accessibility',
  });
  if (await accessibilityButton.isVisible().catch(() => false)) {
    const box = await accessibilityButton.boundingBox();
    if (box != null && box.width > 2 && box.height > 2) {
      await accessibilityButton.click({ force: true });
    } else {
      await accessibilityButton.dispatchEvent('click');
    }
  } else {
    const placeholder = page.locator('flt-semantics-placeholder');
    if (await placeholder.isVisible().catch(() => false)) {
      await placeholder.dispatchEvent('click');
    }
  }
  await expect(page.locator('flutter-view')).toBeVisible();
  await expect(accessibilityButton).toHaveCount(0);
}

export async function openAccount(page) {
  await page.getByRole('button', { name: 'Conta e sincronizacao' }).click();
  await expect(page.getByText('Conta e sincronizacao')).toBeVisible();
}

export async function signIn(page, email, password) {
  await openAccount(page);
  await page.getByLabel('E-mail').fill(email);
  await page.getByLabel('Senha').fill(password);
  await page.getByRole('button', { name: 'Entrar', exact: true }).click();
  await expect(page.getByText('E-mail verificado')).toBeVisible();
}

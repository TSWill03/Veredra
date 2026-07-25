import { expect, test } from '@playwright/test';
import { strToU8, zipSync } from 'fflate';
import { enableFlutterSemantics } from './helpers.mjs';

async function importFile(page, option, file) {
  await page.goto('./');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Importar livro' }).click();

  const escapedOption = option.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const optionButton = page.getByRole('button', {
    name: new RegExp(`^${escapedOption}(?:\\s|$)`),
  });
  const [chooser] = await Promise.all([
    page.waitForEvent('filechooser'),
    optionButton.click(),
  ]);
  await chooser.setFiles(file);
}

function minimalEpub() {
  const containerXml = `<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>`;
  const packageDocument = `<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="book-id" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:identifier id="book-id">urn:uuid:veredra-e2e-minimal</dc:identifier>
    <dc:title>Livro EPUB E2E</dc:title>
    <dc:language>pt-BR</dc:language>
    <dc:creator opf:role="aut">Autor E2E</dc:creator>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="chapter"/>
  </spine>
</package>`;
  const toc = `<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="urn:uuid:veredra-e2e-minimal"/>
  </head>
  <docTitle><text>Livro EPUB E2E</text></docTitle>
  <navMap>
    <navPoint id="chapter" playOrder="1">
      <navLabel><text>Capitulo EPUB E2E</text></navLabel>
      <content src="chapter.xhtml"/>
    </navPoint>
  </navMap>
</ncx>`;
  const chapter = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>Capitulo EPUB E2E</title></head>
  <body>
    <h1>Capitulo EPUB E2E</h1>
    <p>Conteudo extraido de um EPUB minimo valido no navegador.</p>
  </body>
</html>`;

  return Buffer.from(
    zipSync(
      {
        mimetype: [strToU8('application/epub+zip'), { level: 0 }],
        'META-INF/container.xml': strToU8(containerXml),
        'OEBPS/content.opf': strToU8(packageDocument),
        'OEBPS/toc.ncx': strToU8(toc),
        'OEBPS/chapter.xhtml': strToU8(chapter),
      },
      { level: 6 },
    ),
  );
}

test('imports Markdown and renders normalized text', async ({ page }) => {
  await importFile(page, 'Arquivos de texto', {
    name: 'e2e_markdown.md',
    mimeType: 'text/markdown',
    buffer: Buffer.from(
      '# Titulo Markdown E2E\n\nTexto em **negrito** e [link seguro](https://example.test).\n\n- item alfa\n- item beta',
    ),
  });

  await expect(
    page.getByRole('group', { name: /Titulo Markdown E2E/ }),
  ).toBeVisible();
  await expect(
    page.getByRole('group', { name: /Texto em negrito e link seguro/ }),
  ).toBeVisible();
  await expect(
    page.getByRole('group', { name: /\*\*negrito\*\*/ }),
  ).toHaveCount(0);
});

test('imports HTML while removing executable and embedded content', async ({ page }) => {
  await importFile(page, 'Arquivos de texto', {
    name: 'e2e_sanitized.html',
    mimeType: 'text/html',
    buffer: Buffer.from(`<!doctype html>
      <html>
        <body>
          <h1>Capitulo HTML E2E</h1>
          <p>Texto HTML seguro E2E.</p>
          <script>window.__veredraE2eXss = 'HTML_UNSAFE_SENTINEL_E2E';</script>
          <style>.unsafe::before { content: 'HTML_UNSAFE_SENTINEL_E2E'; }</style>
          <iframe>HTML_UNSAFE_SENTINEL_E2E</iframe>
          <object>HTML_UNSAFE_SENTINEL_E2E</object>
          <embed src="data:text/plain,HTML_UNSAFE_SENTINEL_E2E">
          <noscript>HTML_UNSAFE_SENTINEL_E2E</noscript>
        </body>
      </html>`),
  });

  await expect(
    page.getByRole('group', { name: /Texto HTML seguro E2E/ }),
  ).toBeVisible();
  await expect(
    page.getByRole('group', { name: /HTML_UNSAFE_SENTINEL_E2E/ }),
  ).toHaveCount(0);
  await expect
    .poll(() => page.evaluate(() => window.__veredraE2eXss))
    .toBeUndefined();
});

test('imports a minimal valid EPUB generated in memory', async ({ page }) => {
  await importFile(page, 'EPUB', {
    name: 'e2e_minimal.epub',
    mimeType: 'application/epub+zip',
    buffer: minimalEpub(),
  });

  await expect(
    page.getByRole('group', {
      name: /Conteudo extraido de um EPUB minimo valido no navegador/,
    }),
  ).toBeVisible();
  await page.getByRole('button', { name: /^Back/ }).dispatchEvent('click');
  await expect(
    page.getByRole('group', {
      name: /^Livro EPUB E2E EPUB - 1 capitulos Autor E2E - EPUB convertido no navegador - 1 capitulos/,
    }),
  ).toBeVisible();
});

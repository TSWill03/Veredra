"""CTS text runtime v1. Local-only Argos/CTranslate2; no audio, network or UI dependencies."""
from __future__ import annotations

import hashlib
import importlib.metadata
import os
import re
from pathlib import Path

API_VERSION = 1
PROFILES = ("serial", "cpu", "cuda")
_DLL_HANDLES = []


def configure_cuda():
    """Optional explicit DLL paths from the trusted local process configuration."""
    if os.name == "nt":
        for value in os.environ.get("CTS_CUDA_DLL_DIRS", "").split(os.pathsep):
            if not value:
                continue
            path = Path(value).resolve(strict=True)
            if not path.is_dir():
                raise ValueError("CTS CUDA directory is not a directory")
            if hasattr(os, "add_dll_directory"):
                _DLL_HANDLES.append(os.add_dll_directory(str(path)))
            os.environ["PATH"] = str(path) + os.pathsep + os.environ.get("PATH", "")


def split_piece(text, limit=1200):
    pieces = []
    while len(text) > limit:
        window = text[:limit]
        i = max(window.rfind(s) for s in (". ", "! ", "? ", "; ", ", ", " "))
        i = i + 1 if i >= limit // 3 else limit
        pieces.append(text[:i])
        text = text[i:]
    if text:
        pieces.append(text)
    return pieces


def translate_document(translate_many, text):
    """Preserve blank-line layout and source ordering; reject truncated batches."""
    layout, chunks = [], []
    for part in re.split(r"(\n\s*\n+)", (text or "").replace("\r\n", "\n")):
        if not part:
            continue
        if not part.strip():
            layout.append(part)
        else:
            pieces = split_piece(part)
            layout.append((len(chunks), len(chunks) + len(pieces)))
            chunks.extend(pieces)
    if not chunks:
        return "".join(layout)
    outputs = translate_many(chunks)
    if len(outputs) != len(chunks) or any(
        not isinstance(o, str) or (s.strip() and not o.strip())
        for s, o in zip(chunks, outputs)
    ):
        raise RuntimeError("CTS_INVALID_OR_EMPTY_OUTPUT")
    # The boundary whitespace belongs to the source. Do not concatenate
    # two translated words at a split where the model stripped trailing spaces.
    restored = []
    for original, output in zip(chunks, outputs):
        leading = original[:len(original) - len(original.lstrip())]
        trailing = original[len(original.rstrip()):]
        restored.append(leading + output.strip() + trailing)
    return "".join(x if isinstance(x, str) else "".join(restored[x[0]:x[1]]) for x in layout)


def model_identity(engine):
    underlying = getattr(engine, "underlying", engine)
    pkg = getattr(underlying, "pkg", None)
    if pkg is not None:
        model = Path(pkg.package_path) / "model" / "model.bin"
        stat = model.stat()
        return [str(pkg.package_path), str(getattr(pkg, "package_version", "")),
                stat.st_size, stat.st_mtime_ns]
    if hasattr(underlying, "t1") and hasattr(underlying, "t2"):
        return [model_identity(underlying.t1), model_identity(underlying.t2)]
    return [type(underlying).__name__]


class TextEngine:
    """One warm model per worker. GPU initialization may fall back before any output.

    A failure during inference is surfaced to the caller, not silently mixed
    with a different backend in a checkpointed document.
    """
    def __init__(self, source, target, *, profile="cpu", batch_tokens=512,
                 beam_size=4, threads=4, allow_cpu_fallback=False):
        if profile not in PROFILES:
            raise ValueError("Invalid CTS profile")
        if not 32 <= batch_tokens <= 2048 or not 1 <= beam_size <= 8 or not 1 <= threads <= 16:
            raise ValueError("Invalid CTS runtime limits")
        if source == target:
            raise ValueError("Identical language pair")
        from argostranslate import package, settings, translate
        self.source, self.target = source, target
        self.requested_profile = profile
        self.profile = profile
        self.fallback_reason = None
        self.batch_tokens, self.beam_size, self.threads = batch_tokens, beam_size, threads
        self.settings = settings
        # CTS only supports explicitly installed direct model pairs.
        pairs = {(p.from_code, p.to_code) for p in package.get_installed_packages()}
        if (source, target) not in pairs:
            raise LookupError("CTS_DIRECT_MODEL_NOT_INSTALLED: " + source + "->" + target)
        langs = {x.code: x for x in translate.get_installed_languages()}
        self.original = langs[source].get_translation(langs[target])
        self.underlying = getattr(self.original, "underlying", self.original)
        if self.original is None:
            raise LookupError("CTS_TRANSLATION_UNAVAILABLE")
        if profile != "serial" and (importlib.metadata.version("argostranslate") != "1.11.0"
                or not isinstance(self.underlying, translate.PackageTranslation)):
            raise RuntimeError("CTS_BATCH_VERSION_UNSUPPORTED; use serial")
        self.translator = None
        self.compute_type = "default"
        if profile != "serial":
            try:
                self._open(profile)
                self._warmup()
            except Exception as exc:
                if profile != "cuda" or not allow_cpu_fallback:
                    raise
                self.translator = None
                self.profile = "cpu"
                self.fallback_reason = type(exc).__name__
                self._open("cpu")
                self._warmup()
        self.identity = {
            "api_version": API_VERSION,
            "runtime_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "source": source, "target": target,
            "profile": self.profile, "model": model_identity(self.original),
            "argos": importlib.metadata.version("argostranslate"),
            "ctranslate2": importlib.metadata.version("ctranslate2"),
            "batch_tokens": batch_tokens, "beam_size": beam_size, "threads": threads,
            "compute_type": self.compute_type, "chunk_type": str(settings.chunk_type),
            "serial_settings": [str(settings.device), str(settings.compute_type),
                                settings.beam_size, settings.batch_size,
                                settings.intra_threads, settings.inter_threads],
        }

    def _open(self, device):
        if device == "cuda":
            configure_cuda()
        import ctranslate2
        pkg = self.underlying.pkg
        self.translator = ctranslate2.Translator(
            str(Path(pkg.package_path) / "model"), device=device,
            inter_threads=1, intra_threads=self.threads, compute_type=self.compute_type)

    def _warmup(self):
        # A real inference catches missing cuBLAS and runtime incompatibility,
        # not merely a visible GPU. This is excluded from measured warm latency.
        text = {
            "en": "This is a short translation test.",
            "pt": "Este e um teste curto de traducao.",
        }.get(self.source, "1 2 3.")
        self.translate_many([text])

    def translate_many(self, chunks):
        if self.profile == "serial":
            return [self.original.translate(chunk) for chunk in chunks]
        pkg = self.underlying.pkg
        output = []
        for start in range(0, len(chunks), 64):
            subset = chunks[start:start + 64]
            groups, widths = [], []
            for text in subset:
                paragraphs = text.split("\n")
                widths.append(len(paragraphs))
                for paragraph in paragraphs:
                    groups.append([pkg.tokenizer.encode(s) for s in
                                   self.underlying.sentencizer.split_sentences(paragraph)]
                                  if paragraph.strip() else [])
            flat = [sentence for group in groups for sentence in group]
            prefix = [[pkg.target_prefix]] * len(flat) if pkg.target_prefix else None
            results = self.translator.translate_batch(
                flat, target_prefix=prefix, replace_unknowns=True,
                max_batch_size=self.batch_tokens, batch_type="tokens",
                beam_size=self.beam_size, num_hypotheses=1,
                length_penalty=0.2, return_scores=True,
            ) if flat else []
            if len(results) != len(flat):
                raise RuntimeError("CTS_INVALID_BATCH")
            translated_paragraphs = []
            offset = 0
            for group in groups:
                tokens = [t for result in results[offset:offset + len(group)]
                          for t in result.hypotheses[0]]
                offset += len(group)
                value = pkg.tokenizer.decode(tokens) if tokens else ""
                if pkg.target_prefix and value.startswith(pkg.target_prefix):
                    value = value[len(pkg.target_prefix):]
                translated_paragraphs.append(value.removeprefix(" "))
            offset = 0
            for width in widths:
                output.append("\n".join(translated_paragraphs[offset:offset + width]))
                offset += width
        return output

    def translate(self, text):
        if not isinstance(text, str):
            raise TypeError("text must be a string")
        return translate_document(self.translate_many, text)

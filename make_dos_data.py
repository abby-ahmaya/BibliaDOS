#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Gera arquivos de dados para um leitor DOS (Turbo Pascal) a partir do acf_clean.json.

Saida (binario):
  - ACF.DAT : registros (uint16 length + bytes do verso em CP850)
  - ACF.IDX : uint32 offsets (um por verso) apontando para o inicio do registro em ACF.DAT
  - ACF.MET : metadados (nomes/abrevs + contagem de capitulos/versos)

O programa DOS le esses 3 arquivos para navegar por livro/capitulo/verso.
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
import unicodedata
from pathlib import Path
from typing import Any


MAGIC = b"ACFMET"
VERSION = 2
MAX_ABBREV_LEN = 8


def _normalize_text(s: str) -> str:
    # Evita caracteres "combinantes" (ex: 'E' + U+0302) que quebram ao converter
    # para codepages DOS. NFC tende a produzir letras precompostas (ex: 'Ê').
    s = unicodedata.normalize("NFC", s)
    # Pontuacao “bonita” e espacos estranhos viram ASCII simples.
    s = s.replace("\u00a0", " ")
    s = s.replace("\u2013", "-").replace("\u2014", "-")
    s = s.replace("\u2018", "'").replace("\u2019", "'")
    s = s.replace("\u201c", '"').replace("\u201d", '"')
    s = s.replace("\n", " ")
    # Espaços duplicados.
    while "  " in s:
        s = s.replace("  ", " ")
    return s.strip()


def _load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8-sig") as f:
        return json.load(f)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--json",
        default=str((Path(__file__).resolve().parent.parent / "acf_clean.json").resolve()),
        help="Caminho para acf_clean.json/acf.json (UTF-8).",
    )
    ap.add_argument(
        "--outdir",
        default=str(Path(__file__).resolve().parent),
        help="Diretorio de saida (padrao: este diretorio).",
    )
    ap.add_argument(
        "--encoding",
        default="cp850",
        help="Encoding DOS de saida (padrao: cp850).",
    )
    args = ap.parse_args(argv)

    json_path = Path(args.json).expanduser().resolve()
    outdir = Path(args.outdir).expanduser().resolve()
    enc = str(args.encoding)

    if not json_path.exists():
        print(f"ERRO: JSON nao encontrado: {json_path}", file=sys.stderr)
        return 2

    outdir.mkdir(parents=True, exist_ok=True)
    dat_path = outdir / "ACF.DAT"
    idx_path = outdir / "ACF.IDX"
    met_path = outdir / "ACF.MET"

    data = _load_json(json_path)
    if not isinstance(data, list):
        print("ERRO: JSON invalido (esperado lista de livros).", file=sys.stderr)
        return 3

    offsets: list[int] = []
    # (name_bytes, abbrev_bytes, chap_count, verse_counts)
    books_meta: list[tuple[bytes, bytes, int, list[int]]] = []

    with dat_path.open("wb") as dat:
        for book_i, book in enumerate(data):
            if not isinstance(book, dict):
                print(f"ERRO: livro #{book_i} nao e objeto.", file=sys.stderr)
                return 4

            name = _normalize_text(str(book.get("name", "")))
            abbrev = _normalize_text(str(book.get("abbrev", ""))).lower()
            chapters = book.get("chapters")
            if not name or not abbrev or not isinstance(chapters, list):
                print(f"ERRO: livro #{book_i} invalido (name/abbrev/chapters).", file=sys.stderr)
                return 5

            name_b = _normalize_text(name).encode(enc, errors="replace")
            if len(name_b) > 32:
                name_b = name_b[:32]

            abbrev_b = abbrev.encode(enc, errors="replace")
            if len(abbrev_b) > MAX_ABBREV_LEN:
                abbrev_b = abbrev_b[:MAX_ABBREV_LEN]

            verse_counts: list[int] = []
            for chap_i, chap in enumerate(chapters):
                if not isinstance(chap, list):
                    print(
                        f"ERRO: livro '{name}' capitulo {chap_i+1} invalido (esperado lista).",
                        file=sys.stderr,
                    )
                    return 6
                verse_counts.append(len(chap))

                for verse_i, verse in enumerate(chap):
                    text = _normalize_text(str(verse))
                    b = text.encode(enc, errors="replace")
                    if len(b) > 0xFFFF:
                        print(
                            f"ERRO: verso muito grande em {name} {chap_i+1}:{verse_i+1} ({len(b)} bytes).",
                            file=sys.stderr,
                        )
                        return 7
                    offsets.append(dat.tell())
                    dat.write(struct.pack("<H", len(b)))
                    dat.write(b)

            books_meta.append((name_b, abbrev_b, len(chapters), verse_counts))

    with idx_path.open("wb") as idx:
        for off in offsets:
            idx.write(struct.pack("<I", off))

    total_books = len(books_meta)
    total_chaps = sum(ch for _, _, ch, _ in books_meta)
    total_verses = len(offsets)

    with met_path.open("wb") as met:
        met.write(MAGIC)
        met.write(struct.pack("<B", VERSION))
        met.write(struct.pack("<B", total_books))
        met.write(struct.pack("<H", total_chaps))
        met.write(struct.pack("<I", total_verses))

        for name_b, abbrev_b, chap_count, _verse_counts in books_meta:
            met.write(struct.pack("<B", len(name_b)))
            met.write(name_b)
            met.write(struct.pack("<B", len(abbrev_b)))
            met.write(abbrev_b)
            met.write(struct.pack("<B", chap_count))

        for _name_b, _abbrev_b, _chap_count, verse_counts in books_meta:
            for vc in verse_counts:
                met.write(struct.pack("<H", vc))

    print("OK: gerado")
    print("  JSON:", json_path)
    print("  Out :", outdir)
    print("  Livros   :", total_books)
    print("  Capitulos:", total_chaps)
    print("  Versos   :", total_verses)
    print("  Encoding :", enc)
    print("  Arquivos :", dat_path.name, idx_path.name, met_path.name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

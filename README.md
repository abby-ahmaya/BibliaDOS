# Biblia ACF para DOS (EXE)

Este diretorio contem uma versao "DOS de verdade" (Turbo Pascal) do leitor da Biblia ACF, com fundo azul.

Arquivos:

- `BIBLIA.PAS`: fonte Turbo Pascal
- `make_dos_data.py`: gera `ACF.DAT`, `ACF.IDX`, `ACF.MET` a partir do `acf_clean.json`
- `ACF.DAT` / `ACF.IDX` / `ACF.MET`: dados (binario)
- `BIBLIA.EXE`: executavel DOS (gerado)

## Gerar os dados

```bash
cd ~/Downloads/SaturnBible/dos_biblia_acf_dos
python3 make_dos_data.py --json ../acf_clean.json
```

Saida: `ACF.DAT`, `ACF.IDX`, `ACF.MET`.

## Compilar o EXE (Turbo Pascal dentro do DOSBox-X)

O build automatico foi feito via `dosbox-x` com o compilador Turbo Pascal 5.5 (freeware) baixado do "Museum" da Embarcadero.

Build (automatizado neste repo):

```bash
bash /home/pi/compile.sh dos-build /home/pi/Downloads/SaturnBible/acf_clean.json
```

No `dosbox-x`, compile com `TPC.EXE`:

```dos
TPC.EXE /B BIBLIA.PAS
```

Isso gera `BIBLIA.EXE`.

## Rodar

Coloque `BIBLIA.EXE`, `ACF.DAT`, `ACF.IDX`, `ACF.MET` na mesma pasta e rode no DOSBox/FreeDOS:

```dos
START.BAT
```

Teste rapido:

```dos
BIBLIA.EXE /T
```

## Teclas

- `Enter`: selecionar
- `ESC` / `b`: voltar
- `q`: sair
- `F1`: ajuda
- `Setas` / `PgUp` / `PgDn`: navegar
- Menu de livros: `Left/Right` alterna `VT/NT`
- Menu de livros: digite `ap 22 1` e `Enter` para ir direto (livro/cap/verso)
- Leitura: `Left/Right` muda capitulo, `g` vai para verso

## Acentos (importante)

Os textos foram gerados em `CP850` (pt-BR). Se os acentos sairem errados, configure o DOSBox-X para usar codepage 850.

No DOSBox-X, por padrao a codepage costuma ser 437. O `START.BAT` ja faz:

- `CHCP 850`
- `KEYB BR 850`

## Publicar no GitHub

Depois do commit inicial local, conecte seu repositorio remoto e envie:

```bash
git remote add origin https://github.com/SEU_USUARIO/SEU_REPO.git
git branch -M main
git push -u origin main
```

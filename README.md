# Bíblia ACF para DOS

Leitor da Bíblia ACF em modo texto para DOS, feito em Turbo Pascal.
O projeto usa dados binários (`ACF.DAT`, `ACF.IDX`, `ACF.MET`) e executa no DOSBox-X/FreeDOS.

## Screenshots

### Tela de livros

![Tela de livros](screenshots/tela-livros.png)

### Tela de leitura

![Tela de leitura](screenshots/biblia_000.raw1.png)

## Estrutura principal

- `BIBLIA.PAS`: fonte principal (Turbo Pascal)
- `BIBLIA.EXE`: executável DOS compilado
- `make_dos_data.py`: gera `ACF.DAT`, `ACF.IDX`, `ACF.MET` a partir de JSON
- `ACF.DAT` / `ACF.IDX` / `ACF.MET`: base de dados da Bíblia
- `START.BAT`: inicializa codepage/teclado e executa o leitor
- `TP55/`: Turbo Pascal 5.5

## Rodar no DOSBox-X

No DOS (dentro do DOSBox-X), com os arquivos na mesma pasta:

```dos
START.BAT
```

Teste rápido de leitura de arquivos:

```dos
BIBLIA.EXE /T
```

## Compilar o EXE (Turbo Pascal 5.5)

Dentro do DOSBox-X:

```dos
TPC.EXE /B BIBLIA.PAS
```

Também pode compilar direto no host chamando DOSBox-X:

```bash
dosbox-x -fastlaunch -exit \
  -c "mount c /home/pi/dos_biblia" \
  -c "c:" \
  -c "cd \\" \
  -c "TP55\\TPC.EXE /B BIBLIA.PAS"
```

## Gerar os dados ACF

```bash
python3 make_dos_data.py --json /caminho/para/acf_clean.json
```

Saída esperada: `ACF.DAT`, `ACF.IDX`, `ACF.MET`.

## Teclas principais

- `Enter`: selecionar
- `ESC` / `b`: voltar
- `q`: sair
- `F1`: ajuda
- `Setas` / `PgUp` / `PgDn`: navegar
- Livros: `Left/Right` alterna entre colunas VT/NT
- Livros: digite `ap 22 1` e `Enter` para ir direto (livro/capítulo/verso)
- Leitura: `Left/Right` muda capítulo
- Leitura: `g` vai para verso

## Acentos (CP850)

Os dados estão em `CP850` (pt-BR). Se os acentos saírem errados, use codepage 850.

O `START.BAT` já aplica:

- `CHCP 850`
- `KEYB BR 850`

## GitHub

O repositório já está inicializado em `main`. Para publicar:

```bash
git remote add origin https://github.com/SEU_USUARIO/SEU_REPO.git
git push -u origin main
```

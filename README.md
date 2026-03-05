# 📟 BibliaDOS - Retro Bible for Old Computers

[![Download BibliaDOS](https://img.shields.io/badge/Download-BibliaDOS-brightgreen)](https://github.com/abby-ahmaya/BibliaDOS)

---

## 📖 About BibliaDOS

BibliaDOS is a text-based Bible app for MS-DOS and DOS emulators. It offers a retro experience to read the Bíblia ACF (Almeida Corrigida Fiel) in pure DOS mode. This app works well on old computers or through software like DOSBox or FreeDOS. You see the Bible as simple text on the screen, just like computers from the 1980s and 1990s.

The main goal is to allow reading the Bible on machines with limited resources without needing a modern operating system. It does not require a mouse or fancy graphics. Everything runs in the command line environment.

---

## 💻 System Requirements

- Operating system: MS-DOS, FreeDOS, or DOS emulator (like DOSBox)
- CPU: Any PC-compatible processor (386 or higher recommended)
- RAM: Minimum 1 MB (2 MB or more recommended)
- Storage: Around 1 MB free disk space
- Display: Text mode (80x25 characters or above)
- Keyboard: Standard QWERTY or ABNT2 layout for Portuguese

You can use BibliaDOS on original hardware or on modern computers running DOS emulators.

---

## 🚀 Getting Started

1. Click this big button to visit the BibliaDOS page on GitHub and get the app:

   [![Download BibliaDOS](https://img.shields.io/badge/Download-BibliaDOS-blue)](https://github.com/abby-ahmaya/BibliaDOS)

2. On the GitHub page, look for the latest release or download section.

3. Download the BibliaDOS package. It will usually be a ZIP file containing program files and the Bible text.

4. Save the downloaded file on your Windows computer where you can easily find it, like the Desktop or Downloads folder.

---

## 📥 How to Install and Run BibliaDOS on Windows

Since BibliaDOS works in DOS or DOS emulators, you need DOSBox or a similar emulator. Follow these steps to run it smoothly:

### Step 1: Download and Install DOSBox

- Go to the official DOSBox site: https://www.dosbox.com
- Download the latest Windows version.
- Run the installer and follow the instructions to install DOSBox on your PC.

### Step 2: Prepare BibliaDOS Files

- Locate the BibliaDOS ZIP file you downloaded from GitHub.
- Right-click the ZIP and select "Extract All..." or use a tool like 7-Zip.
- Choose a folder on your PC, for example: `C:\BibliaDOS`

### Step 3: Configure DOSBox to Run BibliaDOS

- Open DOSBox from your Start menu.
- Mount the folder where you extracted BibliaDOS as a virtual drive in DOSBox by typing:

  ```
  mount c c:\BibliaDOS
  ```

  Then press Enter.

- Switch to the mounted drive:

  ```
  c:
  ```

- Find the executable file to start BibliaDOS, likely named something like `BIBLIA.EXE` or `BIBLIA.COM`.
- Run the program by typing its name, for example:

  ```
  BIBLIA
  ```

- Press Enter.

### Step 4: Use BibliaDOS

- Follow the on-screen instructions to navigate the Bible.
- Use keyboard arrows, Enter, and ESC keys as directed.
- To exit, usually press `Q` or close DOSBox.

---

## 🔧 Tips for Using BibliaDOS

- BibliaDOS runs best in full-screen text mode but works fine in windowed mode too.
- You can adjust DOSBox window size in its settings if needed.
- Save your place by writing down the chapter and verse since BibliaDOS may not save progress automatically.
- If you use an old PC with MS-DOS or FreeDOS, just copy the files onto a floppy or USB drive and run from there.
- For help or to report issues, check the “Issues” tab on the GitHub page.

---

## 📚 Features of BibliaDOS

- Full text of Bíblia Almeida Corrigida Fiel (ACF) in Portuguese.
- Works on legacy PCs and DOS emulators.
- Simple navigation by book, chapter, and verse.
- No graphical interface needed, low system resource use.
- Small file size, fits on old floppy disks or tiny drives.
- Retro computing feel with pure text mode display.
- Compatible with Turbo Pascal systems if compiled for that environment.

---

## ⚙️ Advanced Setup (Optional)

If you want to customize BibliaDOS for your setup, you can:

- Edit configuration files if available to change display or language options.
- Compile from source if you have Turbo Pascal and want to customize code.
- Use keyboard remapping in DOSBox for better key layouts.

---

## 🔗 Useful Links

- BibliaDOS main page: [https://github.com/abby-ahmaya/BibliaDOS](https://github.com/abby-ahmaya/BibliaDOS)
- DOSBox download: https://www.dosbox.com
- FreeDOS project: http://www.freedos.org

---

## ❓ Troubleshooting

- If BibliaDOS does not start, check that you mounted the correct folder in DOSBox.
- Ensure you typed the executable file name exactly.
- If text looks weird, try changing DOSBox font or screen settings.
- For crashes, increase DOSBox memory or CPU cycles using DOSBox options.
- Use the GitHub Issues section for bug reports or questions.

---

## 🛠 Development and Support

This project is open source. You can visit the GitHub repository to see the source code or contribute.

Tags: acf, bible, biblia, dos, dosbox, freedos, ms-dos, pt-br, retrocomputing, turbo-pascal
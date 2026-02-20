@echo off
rem Biblia ACF (DOS) - launcher
rem DOSBox-X normalmente inicia em CP437; o texto/dados foram gerados em CP850 (pt-BR).
rem Isso corrige acentos como "Êxodo".

chcp 850 >nul
keyb br 850 >nul

biblia.exe


@echo off
echo ========================================
echo  Installation des dependances NLP
echo ========================================

REM Essaie plusieurs commandes Python communes
python -m pip install langdetect textblob deep-translator 2>nul && goto :done
python3 -m pip install langdetect textblob deep-translator 2>nul && goto :done
py -m pip install langdetect textblob deep-translator 2>nul && goto :done

REM Cherche Python dans les emplacements courants
for %%P in (
  "C:\Python39\python.exe"
  "C:\Python310\python.exe"
  "C:\Python311\python.exe"
  "C:\Python312\python.exe"
  "C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python39\python.exe"
  "C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python310\python.exe"
  "C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python311\python.exe"
  "C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python312\python.exe"
) do (
  if exist %%P (
    echo Trouve Python: %%P
    %%P -m pip install langdetect textblob deep-translator
    goto :done
  )
)

echo.
echo ERREUR: Python non trouve automatiquement.
echo Ouvre un terminal dans le dossier de ton projet Flask et tape:
echo    [chemin_vers_ton_python] -m pip install langdetect textblob deep-translator
echo.
pause
exit /b 1

:done
echo.
echo ======================================
echo  Installation terminee avec succes!
echo  Redemarre ton serveur Flask (app.py)
echo ======================================
pause

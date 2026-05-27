# Modulo VBA (Excel) — una sola copia

Questo file è l’**unica** versione da usare: [`VBA_Module_Complete.bas`](./VBA_Module_Complete.bas).

## Evitare funzioni duplicate

1. In VBA (Alt+F11), apri **un** modulo Standard (o creane uno nuovo).
2. **Seleziona tutto il codice nel modulo** (Ctrl+A) e **Elimina** — il modulo deve essere vuoto prima d’incollare.
3. Apri `VBA_Module_Complete.bas` in un editor di testo, **Ctrl+A**, **Ctrl+C**, poi incolla **una sola volta** nel modulo vuoto.
4. **Debug → Compila VBAProject**. Se compare ancora “dichiarazione duplicata”, cerca lo stesso nome `Sub`/`Function` in **altri** moduli del progetto e rimuovi le copie vecchie: nel progetto deve esistere **una sola** definizione per nome.

Non incollare più volte i “blocchi” 1+2+3 se il file già contiene l’intero modulo da riga 1 a 1042.

## Verifica locale (opzionale)

Da shell, nella cartella del file:

```bash
python3 -c "
import re
from collections import Counter
t=open('VBA_Module_Complete.bas',encoding='utf-8').read()
pat=re.compile(r'^\s*(Public|Private)?\s*(Sub|Function)\s+(\w+)\s*[\(\s]', re.M)
d=[n for n,c in Counter(m.group(3) for m in pat.finditer(t)).items() if c>1]
print('OK' if not d else 'Duplicati: '+', '.join(d))
"
```

Se stampa `OK`, non ci sono procedure con lo stesso nome nello stesso file.

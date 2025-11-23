# Generator Semnal PWM - Documentatie Tehnica

## Introducere

Acest proiect reprezinta implementarea in Verilog a unui periferic hardware capabil sa genereze semnale PWM (Pulse Width Modulation). Modulul este proiectat pentru a fi integrat in sisteme embedded si este controlabil printr-o interfata seriala de tip SPI.

Sistemul permite configurarea frecventei (prin perioada si prescaler), a factorului de umplere (duty cycle) si a modului de aliniere a semnalului.

### Arhitectura

Sistemul este compus din 5 module principale conectate in top-level. Fluxul de date porneste de la interfata SPI si ajunge la generatorul de semnal.

![Diagrama Arhitectura](Arhitecture.PNG)

---

## Echipa si Responsabilitati

Proiectul a fost realizat in echipa, sarcinile fiind impartite astfel:

* **Pleseanu Ionut-Cristian:** Implementare modulelor de executie: **Counter** si **PWM Generator**.
* **Lican Stefanita-Ionel-Aurel:** Implementare module **SPI Bridge** si **Instruction Decoder**.
* **Voicu Alexandru-Iulian:** Implementare modul **Registers**.

---

## Descrierea Implementarii Modulelor

### 1. SPI Bridge (spi_bridge.v)
*Responsabil: Lican Stefanita*

> TODO: Aici trebuie completata descrierea despre detectia de fronturi SCLK si shift register.

### 2. Instruction Decoder (instr_dcd.v)
*Responsabil: Lican Stefanita*

> TODO: Aici trebuie completata descrierea despre FSM (SETUP/DATA) si decodificarea adreselor.

### 3. Registers (regs.v)
*Responsabil: Voicu Alexandru*

> TODO: Aici trebuie completata descrierea despre harta memoriei si accesul la registri pe 8 biti vs 16 biti.

### 4. Counter (counter.v)
*Responsabil: Pleseanu Cristian*

Acest modul reprezinta baza de timp a perifericului. Implementarea a urmarit doua obiective principale: scalarea corecta a timpului si stabilitatea la schimbarea parametrilor.

**Detalii de implementare:**

* **Arhitectura cu Registri Tampon (Active Registers):**
    Pentru a asigura coerenta datelor, modulul nu utilizeaza direct intrarile de configurare (`period`, `prescale`, `upnotdown`). In schimb, utilizeaza un set de registri interni "active" (`active_period`, `active_prescale`, `active_upnotdown`).
    Transferul datelor din intrarile utilizatorului in registrii activi se face printr-un mecanism de protectie (`safe_to_update`), care permite actualizarea doar in trei situatii sigure:
    1.  Cand numaratorul este oprit (`!en`).
    2.  In modul *Count Up*: Cand numaratorul a ajuns la valoarea `active_period - 1` (exact inainte de resetare).
    3.  In modul *Count Down*: Cand numaratorul a ajuns la valoarea `1` (exact inainte de a ajunge la 0).
    Acest mecanism garanteaza ca perioada nu se modifica brusc la mijlocul numaratorii, prevenind blocarea contorului in stari invalide (ex: count > period).

* **Sistemul de Prescaler:**
    Scalarea timpului se realizeaza printr-un contor intern pe 32 de biti (`prescaler_cnt`). Limita de numarare este calculata dinamic folosind operatii pe biti: `1 << active_prescale` (echivalent cu $2^{active\\_prescale}$).
    Sistemul genereaza un semnal de tip impuls (`tick`) doar cand acest contor intern atinge limita. Numaratorul principal avanseaza doar la aparitia acestui tick, realizand divizarea frecventei in mod sincron.

* **Logica Principala de Numarare:**
    Numaratorul functioneaza in intervalul `[0, active_period - 1]`.
    * **Modul UP:** Incrementeaza pana la `active_period - 1`, apoi revine la 0.
    * **Modul DOWN:** Decrementeaza pana la 0, apoi sare la `active_period - 1`.
    * **Safety:** Codul include protectii suplimentare pentru cazul in care perioada este setata la 0, fortand iesirea la 0 pentru a evita comportamente nedefinite.

### 5. PWM Generator (pwm_gen.v)
*Responsabil: Pleseanu Cristian*

Acest modul genereaza efectiv forma de unda pe baza valorii curente a numaratorului si a pragurilor setate (`compare1`, `compare2`).

**Detalii de implementare:**

* **Sincronizarea Actualizarii (Safe Update):**
    Pentru a evita coruperea formei de unda la modificarea parametrilor in timp real, modulul utilizeaza un semnal `safe_to_update`.
    Spre deosebire de o abordare simplista care asteapta valoarea 0, acest modul declanseaza actualizarea registrilor tampon (`active_compare`, `active_functions`) exact la finalul perioadei curente: `count_val == active_period - 1`. Aceasta asigura ca noii parametri intra in vigoare instantaneu la primul ciclu de ceas al noii perioade.

* **Logica de "Look-Ahead":**
    In blocul de generare a semnalului, comparatiile se fac utilizand formula `active_compare - 1`.
    * *Motivatie:* In logica secventiala sincrona, o decizie luata la frontul de ceas $N$ se propaga la iesire la frontul $N+1$. Prin compararea cu `compare - 1`, comanda de basculare a semnalului este data cu un ciclu in avans, astfel incat tranzitia fizica pe pinul `pwm_out` sa aiba loc exact in momentul in care numaratorul atinge valoarea de prag.

* **Gestionarea Modurilor de Aliniere:**
    * **Unaligned (Functia 2):** Utilizeaza doua puncte de comutare. Seteaza iesirea pe 1 la `Compare1` si o sterge la `Compare2`.
    * **Aligned (Functia 0 si 1):** Utilizeaza o logica de tip "Toggle" (`out <= ~out`). Starea initiala (1 pentru Left-Aligned, 0 pentru Right-Aligned) este pre-calculata si fortata in blocul de update, iar tranzitia are loc prin inversarea starii curente la atingerea pragului `Compare1`.

* **Prevenirea Starilor Nedefinite:**
    In momentul actualizarii parametrilor, codul include o logica explicita de initializare a variabilei `out` (0 sau 1 in functie de functia aleasa: Left/Right/Unaligned). Acest lucru elimina riscul ca semnalul sa ramana inversat daca utilizatorul schimba modul de functionare din mers.

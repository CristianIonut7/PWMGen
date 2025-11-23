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

Acest modul reprezinta interfata de comunicatie dintre periferic si mediul extern folosind protocolul SPI. Rolul lui este sa sincronizeze bitii primiti de pe MOSI, sa genereze octeti validi pentru sistemul intern si sa trimita inapoi date catre master prin MISO.

**Detalii de implementare:**

* **Sincronizarea Semnalelor Externe:**
    Semnalele SPI (`SCLK`, `CS`, `MOSI`) sunt nesincrone fata de ceasul intern al perifericului. Pentru a preveni metastabilitatea, modulul utilizeaza registre de sincronizare pe doua niveluri:
    - `sclk_sync[1:0]`
    - `cs_sync[1:0]`
    - `mosi_sync[1:0]`
    
    Dupa sincronizare, logica interna lucreaza doar cu semnale stabile.

* **Detectarea Fronturilor de Clock:**
    Protocolul SPI cu `CPOL = 0` si `CPHA = 0` necesita:
    - Preluarea datelor pe **frontul crescator** al lui `SCLK`
    - Deplasarea datelor catre MISO pe **frontul descrescator**
    
    Pentru acest lucru se genereaza semnalele:
    - `sclk_rise` – detecteaza tranzitia 0 → 1
    - `sclk_fall` – detecteaza tranzitia 1 → 0
    
    Aceste semnale permit implementarea corecta a fluxului MOSI/MISO.

* **Shift Register pentru Receptie (MOSI):**
    La fiecare **front crescator** al lui `SCLK`, bitul curent de pe linia MOSI este capturat:
    ```
    shift_in <= {shift_in[6:0], MOSI_bit};
    ```
    Dupa 8 capturi consecutive, modulul semnaleaza ca un octet complet a fost receptionat:
    - `rx_valid = 1` pentru un singur ciclu
    - `rx_data[7:0]` contine octetul final

    Acest octet este transmis catre modulul **Instruction Decoder**.

* **Shift Register pentru Transmitere (MISO):**
    In momentul in care `CS` devine 0, se incarca in registrul de transmitere octetul primit de la modulul **Registers**:
    ```
    shift_out <= tx_data;
    ```
    Pe fiecare **front descrescator** al lui `SCLK`, registrul deplaseaza bitul urmator catre MISO:
    ```
    shift_out <= {shift_out[6:0], 1'b0};
    ```
    Primul bit transmis este intotdeauna MSB, conform standardului SPI.

* **Gestionarea semnalului CS:**
    Cand `CS = 1`:
    - transmisia si receptia sunt oprite
    - registrele interne sunt resetate
    - numaratoarele se golesc
    
    Cand `CS = 0`:
    - incepe un nou cadru SPI
    - registrele de shift sunt activate
    - se numara cei 8 biti ai transferului

* **Interfata Catre Sistemul Intern:**
    SPI Bridge furnizeaza:
    - `rx_data[7:0]` – octet receptionat
    - `rx_valid` – puls de confirmare
    - `tx_data[7:0]` – octet de trimis
    - `tx_load` – semnal de incarcare

    Acestea conecteaza modulul la **Instruction Decoder** si **Registers**.

---

### 2. Instruction Decoder (instr_dcd.v)
*Responsabil: Lican Stefanita*

Acest modul interpreteaza datele receptionate prin SPI Bridge si genereaza semnalele necesare modulului Registers. Functioneaza ca un FSM (Finite State Machine) care proceseaza byte-ii receptionati si decide operatiile perifericului: citire sau scriere in registri.

---

## Detalii de implementare

### 1. Faza de Setup
Primul byte dintr-un transfer SPI contine informatiile pentru operatiune. Structura byte-ului este urmatoarea:

| Bit   | Denumire     | Semnificatie |
|-------|--------------|--------------|
| 7     | Read/Write   | 1 = scriere (Write), 0 = citire (Read) |
| 6     | High/Low     | 1 = MSB [15:8], 0 = LSB [7:0] |
| 5:0   | Address      | Adresa registrului tinta |

- Modul receptioneaza byte-ul de la SPI Bridge (`rx_data`)  
- FSM-ul retine valorile pentru `read/write`, `high/low` si `address`  
- Aceasta faza stabileste daca urmatorul transfer va fi citire sau scriere si zona registrului tinta  

### 2. Faza de Data
In aceasta faza se transmit sau se receptioneaza datele efective:

- Datele sunt pe 8 biti, chiar daca registrii din modul Registers sunt pe 16 biti  
- Pentru scriere, FSM-ul trimite byte-ul catre registru folosind semnalele `write_enable` si `write_high_low`  
- Pentru citire, FSM-ul solicita registrului byte-ul corespunzator si il transmite inapoi catre SPI Bridge prin `tx_data`  
- Transferul este sincronizat cu semnalele `rx_valid` si `tx_load` de la SPI Bridge  

### 3. Logica FSM si sincronizare
- FSM-ul trece din faza Setup in faza Data dupa receptionarea primului byte  
- Fiecare byte receptionat genereaza un puls intern (`rx_ready`) care declanseaza logica FSM  
- Fiecare transfer este efectuat complet, bit cu bit, fara pierderi de date  

### 4. Protectia integritatii datelor
- Se utilizeaza registre tampon pentru a retine temporar datele receptionate  
- FSM-ul asigura ca niciun byte nu este pierdut sau suprascris  
- Daca `CS = 1`, FSM-ul se reseteaza si asteapta urmatorul transfer SPI  

Aceasta arhitectura permite perifericului sa interpreteze corect comenzile master-ului si sa efectueze operatiile pe registri fara erori sau pierderi de date.




### 3. Registers (regs.v)
*Responsabil: Voicu Alexandru*💾

Modulul **regs.v** reprezintă mediul de stocare și configurare pentru întreg perifericul PWM. Acesta conectează decodorul de instrucțiuni cu modulele Counter și PWM Generator, asigurând o interfață coerentă, stabilă și sincronă pe o magistrală de date de doar 8 biți. Rolul său este de a primi comenzi de scriere/citire prin SPI, de a actualiza registre interne și de a furniza modulelor hardware valorile necesare funcționării.

---

### **Structura Generală a Registrelor**

Registrele implementate includ:

- **PERIOD (period_low, period_high)** – definește perioada PWM.
- **COMPARE1 / COMPARE2 (low/high)** – pragurile de comutare PWM.
- **PRESCALE** – divizorul de frecvență al contorului.
- **UPDOWN** – modul de numărare (în sus / în jos).
- **FUNCTIONS** – modul de generare PWM (Aligned Left/Right, Unaligned).
- **COUNTER_RESET** – scriere = impuls pentru resetarea contorului.
- **COUNTER_VAL (low/high)** – valoarea curentă a contorului (read-only).

Toate registrele pe 16 biți sunt mapate pe câte **două adrese consecutive**.

---

### **Adresarea pe Octeți (Byte Addressing)**

Magistrala internă este pe **8 biți**, în timp ce multe dintre registre necesită **16 biți** pentru configurare. Astfel, structura este:

- `Address` → octetul Low  
- `Address + 1` → octetul High  

Exemple:

- `0x00` → PERIOD_LOW  
- `0x01` → PERIOD_HIGH  
- `0x02` → COMPARE1_LOW  
- `0x03` → COMPARE1_HIGH  

Această abordare:

1. Permite un transfer gradual al valorilor dinspre SPI.
2. Previne conflictele de sincronizare între byte-ul low și high.
3. Simplifică decodorul de instrucțiuni, care trimite mereu doar 8 biți.

---

### **Organizarea Internă: Două Blocuri Always Complementare**

#### **1. Bloc Secvențial (posedge clk / negedge rst_n)**  
Acest bloc modelează registrele hardware reale.

Responsabilități:

- Aplicarea **resetului asincron**.
- Realizarea operațiilor de **scriere (write_enable)**.
- Actualizarea doar a octetului relevant în funcție de adresă.
- Manipularea logicii pentru registrele speciale (ex: COUNTER_RESET).

Caracteristici:

- Folosește **atribuiri non-blocante (`<=`)**, pentru a reflecta modul de funcționare al flip-flop-urilor.
- Garantează că valorile sunt stabilizate pentru ciclul următor de ceas.

---

#### **2. Bloc Combinatoriu (always @*)**  
Acest bloc modelează un multiplexor mare responsabil de **citirea registrelor**.

Responsabilități:

- Selectarea corectă a valorii de trimis pe `data_read`, în funcție de adresă.
- Împărțirea registrelor pe 16 biți în octeți Low/High.
- Expansiunea registrelor pe 1 bit în format pe 8 biți.
- Accesarea specială a registrului read-only `COUNTER_VAL`.

Caracteristici:

- Nu include operații de scriere sau memorare.
- Răspunsul este combinatoriu și nu depinde de ceas.
- Registrele write-only returnează `8'h00`.

---

### **Gestionarea Resetului Contorului (COUNTER_RESET)**

Registrul `COUNTER_RESET` (adresa `0x07`) este implementat ca un mecanism special pentru generarea unui **impuls de reset pe un singur ciclu de ceas**, indiferent de valoarea scrisă.

Comportament:

1. Când se scrie în adresa `0x07`, blocul secvențial setează `count_reset <= 1`.
2. La ciclul următor de ceas, semnalul este resetat automat la `0`.
3. Nu există stocare permanentă – este un registru virtual, util pentru declanșarea acțiunilor momentane.

Avantaje:

- Reset clar și controlat.
- Nu poate rămâne blocat în starea „activ”.
- Evită problemele din sincronizarea cu modul Counter.

---

### **Citirea Valoarii Contorului (COUNTER_VAL)**

Registrele `0x08` și `0x09` sunt **Read-Only**. Ele nu folosesc memorie internă:

- În loc să stocheze valori, logica combinatorie citește direct intrarea `counter_val[15:0]`.
- Datele citite reflectă exact starea contorului în ciclul curent de ceas.
- Se elimină complet riscul de dezaliniere între contor și modulul Registers.

Această abordare este ideală pentru monitorizarea în timp real a perifericului.

---

### **Rezumat al Fluxului de Operare**

1. SPI trimite un byte de scriere.
2. Instruction Decoder furnizează `addr`, `data_write`, `write_enable`.
3. Blocul secvențial actualizează registrele interne.
4. Modulele Counter și PWM Generator folosesc valorile stabile.
5. La cererea de citire, blocul combinatoriu plasează pe magistrală octetul corespunzător.

Acest design asigură:

- izolare clară între logica de comunicare și logica funcțională,
- consistență între byte-ul HIGH și LOW,
- comportament determinist și sigur pentru modularea PWM.




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

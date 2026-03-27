# **Formale Validierung eines Ada-Forth-Interpreters mittels SPARK: Architektur- und Verifikationsanalyse**

## **1\. Einleitung in die formale Programmverifikation und Projektübersicht**

Die Entwicklung von hochzuverlässiger und sicherheitskritischer Software erfordert Paradigmen, die weit über das klassische, testbasierte Vorgehen hinausgehen. Während dynamische Tests die Präsenz von Fehlern nur unter vorab definierten Bedingungen aufzeigen können, zielen formale Methoden auf den rigorosen mathematischen Beweis der Fehlerfreiheit ab. In diesem anspruchsvollen Kontext stellt SPARK, ein streng reglementiertes und formales Subset der Programmiersprache Ada, eine der etabliertesten Technologien für die Konstruktion sicherer Systeme dar.1

Das vorliegende Projekt implementiert einen interaktiven Forth-Interpreter in Ada 2012 / SPARK 2014 und liefert einen bemerkenswerten Beleg für die Anwendbarkeit dieser Methoden: Es weist **exakt null unbewiesene Verifikationsbedingungen (Verification Conditions)** auf. Jeder einzelne der 424 logischen Prüfpunkte der Kernlogik wurde formal durch die GNATprove-Toolchain bewiesen.

Forth ist historisch als extrem hardwarenahe Programmiersprache bekannt, die häufig unkontrollierte Pointer-Arithmetik verwendet und auf strenge Typisierung verzichtet. In sicherheitskritischen eingebetteten Systemen (für die auch dieses Projekt durch das build\_minimal.sh Skript und pragma No\_Run\_Time optimiert ist), können Stack-Overflows oder illegale Speicherzugriffe katastrophale Konsequenzen nach sich ziehen.

Um dies zu verhindern, modelliert dieses Projekt den Interpreter als strikt deterministische Virtuelle Maschine mit einer isolierten 3-Schichten-Architektur:

1. **Foundation**: Bounded\_Stacks (generische, beweisbare Stack-Struktur)  
2. **Virtual Machine**: Forth\_VM (Kernzustand, Speicher, Wörterbuch, Primitiv-Operationen)  
3. **Outer Interpreter**: Forth\_Interpreter (Tokenizer, Compiler, Kontrollfluss)

Dieser Bericht analysiert die mechanischen Abläufe der SPARK-Verifikation in extremer Detailtiefe, definiert die relevante Terminologie anhand konkreter Codebeispiele dieses Repositories und bewertet die weitreichenden architektonischen Entscheidungen, die getroffen wurden, um diese 100%ige Beweisquote zu erreichen.

## **2\. Technischer Glossar: Verifikationskonzepte im Projektkontext**

Um die komplexe Mechanik der formalen Verifikation in diesem spezifischen Interpreter-Projekt vollständig zu durchdringen, ist eine präzise Definition der zugrundeliegenden Konzepte und Annotationsmechanismen unerlässlich.

### **Abstract State (Abstrakter Zustand)**

Ein abstrakter Zustand ist ein Mechanismus in SPARK, um interne, globale Zustände eines Moduls vor der Außenwelt logisch zu verbergen.2 Interessanterweise nutzt dieses Projekt **keine** globalen abstrakten Zustandsmaschinen, um Seiteneffekte zu vermeiden. Stattdessen wird der Zustand explizit in einem Record (type VM\_State is record...) gekapselt und als in out-Parameter (VM : in out VM\_State) durchgereicht. Jedoch verwendet das Bounded\_Stacks-Paket type Stack is private;, was als Abstrakter Datentyp (ADT) fungiert, dessen interne Array-Struktur vor der VM verborgen bleibt.

### **Assertion (Zusicherung)**

Eine Zusicherung ist ein logischer Ausdruck, der explizit in den Ausführungsfluss eingebettet wird und zwingend wahr sein muss.3 In SPARK fungieren sie primär als statische Prüfpunkte für den Theorembeweiser.4 *Beispiel im Code*: In Forth\_VM.Finalize\_Definition wird pragma Assert (VM.Dictionary (VM.Dict\_Size).Length \> 0); verwendet, um dem SMT-Solver einen Zwischenschritt in der Logik nach dem Hinzufügen eines Wortes ins Dictionary zu demonstrieren.

### **Counterexample (Gegenbeispiel)**

Wenn der Theorembeweiser eine Bedingung nicht beweisen kann, generiert er ein Gegenbeispiel, das zeigt, unter welchen konkreten Variablenwerten die Spezifikation verletzt wird.5 Da in diesem Projekt alle 424 VCs bewiesen sind, treten im finalen Code keine Gegenbeispiele mehr auf. Während der Entwicklung hätten Gegenbeispiele jedoch beispielsweise gezeigt, welche exakten Stack-Werte in Execute\_Add zu einem Überlauf von Integer'Last geführt hätten.

### **Data Dependencies & Information Flow (Daten- und Informationsfluss)**

SPARK analysiert präzise, wie Informationen durch Variablen fließen.7

* **Data Dependencies**: Definiert, welche Ausgaben von welchen Eingaben abhängen.  
* **Information Flow**: Verhindert versteckte Kopplungen zwischen Variablen (Covert Channels).7 Durch die strikte Übergabe von VM\_State als Parameter stellt SPARK hier sicher, dass Funktionen wie Execute\_Dup den Zustand des Interpreters nur exakt so modifizieren, wie es der Vertrag erlaubt.

### **Flow Analysis (Datenflussanalyse)**

Die Flow-Analyse ist die erste Phase von GNATprove und operiert ohne SMT-Solver extrem schnell.8 Sie garantiert, dass Variablen initialisiert werden, bevor sie gelesen werden.8 In diesem Projekt hat die Flow-Analyse erfolgreich 71 Initialisierungs-VCs und 17 Terminierungs-VCs bewiesen.

### **Ghost Code (Geistercode)**

Ghost Code umfasst Funktionen oder Variablen, die ausschließlich für die formale Verifikation existieren und vom Compiler bei der Generierung des Maschinencodes vollständig entfernt werden.9 *Beispiel im Code*: In Bounded\_Stacks.ads wird function Element\_At (S : Stack; I : Positive) return Integer with Ghost; definiert. Sie wird in der Nachbedingung von Push und Pop verwendet, um logisch zu beweisen, dass Elemente am Boden des Stacks unangetastet bleiben, kostet aber zur Laufzeit keinerlei Performance.

### **GNATprove & Why3**

GNATprove ist die SPARK-Toolchain, die den Code parst und die Beweisverpflichtungen generiert.10 Why3 ist die intermediäre Verifikationsplattform, die diese Formeln übersetzt und an mathematische Solver verteilt.11 Im Build-Skript dieses Projekts wird explizit gnatprove... \--prover=alt-ergo aufgerufen, womit angewiesen wird, ausschließlich den Solver "alt-ergo" zu verwenden.

### **Invariant (Schleifeninvariante)**

Eine Schleifeninvariante (Loop\_Invariant) ist eine logische Aussage, die vor, während und nach einer Schleife wahr bleiben muss.12 *Beispiel im Code*: Der Kern des Interpreters, Execute\_Word (der "Inner Interpreter"), enthält eine Endlosschleife, in der Instruktionen verarbeitet werden. Hier finden sich essenzielle Invarianten wie pragma Loop\_Invariant (VM\_Is\_Valid (VM)); und pragma Loop\_Invariant (Steps \<= Max\_Exec\_Steps);, die garantieren, dass die VM bei jedem Schritt intakt bleibt und die Schleife terminiert.

### **Precondition und Postcondition (Vor- und Nachbedingungen)**

Diese Bedingungen definieren die Schnittstellen (Design by Contract).13 *Beispiel im Code*: In Forth\_VM.ads lautet der Vertrag für Execute\_Drop: Pre \=\> VM\_Is\_Valid (VM) and then not Data\_Stacks.Is\_Empty (VM.Data\_Stack) Post \=\> VM\_Is\_Valid (VM) Der Beweiser erlaubt den Aufruf von Drop nur, wenn bewiesen ist, dass der Datenstack zuvor nicht leer ist.

### **Proof Obligation / Verification Condition (Beweisverpflichtung)**

Eine Beweisverpflichtung (VC) ist eine mathematische Formel, die aus dem Code abgeleitet wird und logisch zwingend beweisbar sein muss, damit der Code fehlerfrei ist.14 Dieses Projekt erzeugte genau 424 solcher VCs.

### **SPARK**

SPARK ist eine stark eingeschränkte Teilmenge von Ada. Durch das strikte Verbot von Sprachfeatures, die Aliasing (Mehrdeutigkeiten durch Zeiger) erzeugen, schafft SPARK einen deterministischen Raum für vollständige statische Analysen.1 Dies wird im Projekt durch pragma SPARK\_Mode \=\> On erzwungen.

## ---

**3\. Formale Validierung im Detail: Der Verifikationsprozess**

Die Verifikation des Ada-Forth-Interpreters wird automatisiert über die CI/CD-Pipeline (ci.yml) oder lokal per Kommandozeile gesteuert.

### **3.1 Die Phasen der Pipeline**

**Phase 1: Syntaktische Prüfung**

Der GNAT-Compiler verifiziert durch pragma SPARK\_Mode \=\> On, dass in Modulen wie Forth\_VM keine Ausnahmen (Exceptions), keine Pointer und keine dynamische Allokation (new) verwendet werden.

**Phase 2: Flow-Analyse**

Wie in der Zusammenfassung in README.md dokumentiert, übernimmt die Flow-Analyse 88 Beweisverpflichtungen: Sie beweist 71 Initialisierungen (z.B. dass das Dictionary vor der Nutzung durch Initialize korrekt präpariert wird) und 17 Terminierungsbedingungen.

**Phase 3: Proof Obligation Generation & Beweis** Der Kern der Logik – 336 VCs für Laufzeitprüfungen (Run-time Checks), Assertions und funktionale Verträge (Functional Contracts) – wird in die mathematische Zwischensprache Why3 übersetzt 11 und vom Solver alt-ergo geprüft. Alt-ergo beweist hier beispielsweise lückenlos, dass die 10.000 Max\_Exec\_Steps niemals zu einem Integer-Überlauf führen und dass Array-Zugriffe für Variablen (VM.Memory (Addr)) immer innerhalb der validen Grenzen (0.. Max\_Variables \- 1\) liegen.

### **3.2 Interpretation der Projekt- und Beweisdateien**

Das Verzeichnis obj/ enthält Artefakte, die den Beweisfortschritt speichern:

* **.cswi (Compiler Switch Information):** Diese Dateien (z.B. forth\_vm.cswi) speichern die Parameter (-gnatA, \-gnat2012, \-gnata) zum Zeitpunkt der Analyse. Sie ermöglichen GNATprove, inkrementell zu arbeiten und nur geänderte Dateien neu zu beweisen, anstatt bei jedem Aufruf alle 1.996 Zeilen neu berechnen zu müssen.16  
* **.bexch (Binder Exchange):** Eine Datei wie main.bexch wird vom gprbind-Tool erzeugt. Sie stellt sicher, dass die verifizierten Objekte (wie forth\_vm.o und bounded\_stacks.o) in einer validen Reihenfolge gebunden werden und keine Versionskonflikte bestehen.17

### **3.3 Verifikations-Ergebnisse des Projekts**

Das Ergebnis dieses spezifischen Projekts ist makellos:

| Kategorie | VCs | Prover |
| :---- | :---- | :---- |
| Initialization | 71 | Flow Analysis |
| Run-time Checks | 148 | alt-ergo |
| Assertions | 39 | alt-ergo |
| Functional Contracts | 149 | alt-ergo |
| Termination | 17 | Flow Analysis |
| **Total** | **424** | **0 Unproved** |

Das Projekt produziert **keine Counterexamples** und keine Timeouts, was bedeutet, dass der Solver mathematisch für *alle* möglichen Eingaben garantiert, dass das Programm sicher ausgeführt wird.

## ---

**4\. Projekt-Design-Analyse: Architektonische Entscheidungen für Verifizierbarkeit**

Um eine 100%ige Beweisquote für eine Virtuelle Maschine in SPARK zu erreichen, wurden hochintelligente Kompromisse und Designmuster angewandt. Die Kernparadigmen von Forth (Speichermanipulation) und SPARK (strikte mathematische Sicherheit) wurden hier meisterhaft synthetisiert.

### **4.1 Die Motivation: Absolute Speichersicherheit bei \~7 KB Footprint**

Die bewusste Entscheidung für SPARK (im No\_Run\_Time / Minimal-Build-Szenario) liegt in der Anforderung begründet, garantierte Ausfallsicherheit ohne den Overhead eines Garbage Collectors oder traditionellen Speicherschutzes zu erreichen. Die gesamte statische Struktur (256 Stack-Elemente, 64 Dictionary-Einträge, 1024 Instruktionen) belegt nur \~7 KB. SPARK beweist, dass diese extrem engen Puffer niemals überlaufen. Dies prädestiniert das Projekt für kritische Embedded Systems.

### **4.2 Verzicht auf Pointer zugunsten von Subtypen**

Die Architektur verzichtet konsequent auf "Threaded Code" und Funktionszeiger, da Access Types (Pointer) die SPARK-Verifikation exponentiell verkomplizieren würden. Stattdessen werden stark typisierte Arrays verwendet:

subtype Code\_Index is Positive range 1.. Max\_Code\_Size;

Das enorm komplexe Problem der Speichersicherheit (Vermeidung von Segfaults) wird dadurch auf ein für SMT-Solver triviales Array-Bounds-Checking reduziert. Der Instruktionszeiger (PC) wird vom Solver einfach als numerischer Wert innerhalb der Code\_Index-Grenzen validiert.

### **4.3 Treibstoff für den Beweiser: Vermeidung von Rekursion**

Eine der faszinierendsten Entscheidungen ist die Implementierung von Execute\_Word (dem Inner Interpreter). Traditionell können Forth-Wörter sich selbst aufrufen (Rekursion). SPARK erfordert für Rekursion jedoch eine Variante (Subprogram\_Variant), die beweist, dass die Rekursionstiefe schrumpft. Bei dynamischen Interpreter-Aufrufen ist dies logisch unmöglich zu beweisen.

Das Projekt umgeht dies genial: Es eliminiert die Ada-seitige Rekursion vollständig. Stattdessen verwendet Execute\_Word eine flache Endlosschleife und manipuliert einen separaten, expliziten 64-Elemente großen Return\_Stack. Um SPARK dennoch eine Garantie der Terminierung zu geben, nutzt das Design ein "Fuel"-Konzept:

Max\_Exec\_Steps : constant := 10\_000;

Die Schleifeninvariante pragma Loop\_Invariant (Steps \<= Max\_Exec\_Steps); beweist, dass der Interpreter selbst bei einer vom Nutzer programmierten Forth-Endlosschleife nach 10.000 Instruktionen deterministisch anhält (Halted-State) und niemals einfriert.

### **4.4 Komposition durch Modulstruktur**

Das System ist in drei entkoppelte Graphen unterteilt, was die *Assume-Guarantee*\-Komposition 18 ermöglicht:

1. Die Stack-Operation (Bounded\_Stacks) wird isoliert bewiesen.  
2. Die VM (Forth\_VM) "vertraut" dem Vertrag von Bounded\_Stacks und nutzt ihn, um Primitiv-Ausführungen (wie Execute\_Add) zu beweisen.  
3. Der Compiler (Forth\_Interpreter) nutzt die VM-Verträge (VM\_Is\_Valid), um lexikalische Parsing-Schleifen zu beweisen.  
   Ohne diese Schichtungstrennung würde der alt-ergo Solver in eine "State Explosion" laufen und scheitern.

## ---

**5\. Praktische Ergebnisse: Code-Qualität und Vollständigkeit**

### **5.1 Wo formale Methoden nützlich sind**

Die Verifikation im vorliegenden Code ersetzt de facto hunderte traditionelle Unit-Tests. Ein Beispiel ist die Try\_Parse\_Integer-Funktion. GNATprove beweist mit Accum \> (Long\_Long\_Integer'Last \- Digit) / 10, dass der Parser für String-zu-Integer-Konvertierungen niemals eine Exception auslöst, auch wenn ein Nutzer extrem lange Ziffernfolgen wie "9999999999999999999" eingibt.

Ebenso schützt das System vor Arithmetic Overflow: In Execute\_Add wird in Long\_Long\_Integer berechnet und das Ergebnis manuell gegen Int\_Min und Int\_Max geprüft, bevor der Stack modifiziert wird. Ein Constraint\_Error ist somit formal ausgeschlossen.

### **5.2 Grenzen der Verifikation**

Die Verifikation deckt die gesamte Logik ab, endet jedoch an der I/O-Grenze der realen Welt. Das Paket main.adb und das Minimal-IO-Paket mini\_io.adb sind absichtlich mit pragma SPARK\_Mode \=\> Off annotiert. Der Beweiser kann I/O-Funktionen der Linux-Ebene (read, write, Ada.Text\_IO) nicht mathematisch modellieren. Dies ist ein Standardkompromiss in SPARK-Projekten: Die Kernlogik ist zu 100% bewiesen, während die schmale Außenhülle unbewiesen bleibt.

## ---

**6\. Fazit und Synthese der Lernziele**

Die Analyse dieses dedizierten Projekts (ein SPARK-Forth-Interpreter, der mit KI-Unterstützung von Kiro Pro+ entwickelt wurde) liefert hervorragende Einsichten in die Praxis formaler Methoden:

**1\. Anwendung formaler Methoden in der Praxis:**

Dieses Repository demonstriert perfekt "Design for Verification". Die formale Beweisbarkeit erfordert, von Beginn an auf Pointers zu verzichten, Rekursionen in flache State-Machines umzuwandeln (Fuel-Bounding) und Operationen so klein zu schneiden, dass ein SMT-Solver wie alt-ergo sie erfassen kann.

**2\. Design-Entscheidungen für Verifizierbarkeit:**

Die Umstellung des Forth-"Threaded Code" auf einen einfachen Array-Index (Code\_Index) ist eine meisterhafte Anpassung an den Theorembeweiser. Das System opfert die Fähigkeit zur Laufzeit dynamisch Speicher für Endlos-Skripte anzufordern, gewinnt dafür aber absolute, bewiesene Sicherheit vor Speicherfehlern.

**3\. Balance zwischen Aufwand und Sicherheitsgewinn:**

Obwohl SPARK einen signifikant höheren initialen Schreibaufwand verlangt (hier die präzisen Pre/Post-Bedingungen und Ghost-Funktionen), zeigt das Projektprotokoll einen massiven Gewinn: Die gesamten erweiterten Operationen (Variablen, Kontrollfluss) wurden in extrem kurzer Zeit (\~4.5 Stunden mit KI-Unterstützung) implementiert und die resultierenden 424 VCs mathematisch versiegelt. Der Beweis ersetzt monatelanges Testen auf Edge-Cases wie Stack-Underflows in komplex verzweigten Forth-Kontrollstrukturen.

Das Projekt dokumentiert eindrucksvoll: Wenn die Software-Architektur sich den mathematischen Regeln von SPARK beugt, entsteht als Resultat robuster, laufzeitsicherer Code (AoRTE \- Absence of Run-Time Errors), der selbst den härtesten Anforderungen eingebetteter Systeme standhält.

#### **Works cited**

1. A Practical Introduction to Formal Development and Verification of High-Assurance Software with SPARK, accessed March 27, 2026, [https://secdev.ieee.org/wp-content/uploads/2019/09/SPARK-Tutorial-Slides.pdf](https://secdev.ieee.org/wp-content/uploads/2019/09/SPARK-Tutorial-Slides.pdf)  
2. 5.3. Package Contracts — SPARK User's Guide 27.0w \- Documentation \- AdaCore, accessed March 27, 2026, [https://docs.adacore.com/spark2014-docs/html/ug/en/source/package\_contracts.html](https://docs.adacore.com/spark2014-docs/html/ug/en/source/package_contracts.html)  
3. Auto-Active Proof of Red-Black Trees in SPARK? \- AdaCore, accessed March 27, 2026, [https://www.adacore.com/uploads/blog/Auto-Active-Proof-of-Red-Black-Trees-in-SPARK.pdf](https://www.adacore.com/uploads/blog/Auto-Active-Proof-of-Red-Black-Trees-in-SPARK.pdf)  
4. Integrated Environment for Diagnosing Verification Errors \- Microsoft, accessed March 27, 2026, [https://www.microsoft.com/en-us/research/wp-content/uploads/2016/07/ide-1.pdf](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/07/ide-1.pdf)  
5. 7.9.1. Basic Examples — SPARK User's Guide 27.0w \- Documentation \- AdaCore, accessed March 27, 2026, [https://docs.adacore.com/spark2014-docs/html/ug/en/source/basic.html](https://docs.adacore.com/spark2014-docs/html/ug/en/source/basic.html)  
6. SPARK 16: Generating Counterexamples for Failed Proofs \- AdaCore, accessed March 27, 2026, [https://www.adacore.com/blog/spark-16-generating-counterexamples-for-failed-proofs](https://www.adacore.com/blog/spark-16-generating-counterexamples-for-failed-proofs)  
7. 1\. Introduction — SPARK Reference Manual 27.0w \- Documentation, accessed March 27, 2026, [https://docs.adacore.com/spark2014-docs/html/lrm/introduction.html](https://docs.adacore.com/spark2014-docs/html/lrm/introduction.html)  
8. Flow Analysis \- learn.adacore.com, accessed March 27, 2026, [https://learn.adacore.com/courses/intro-to-spark/chapters/02\_Flow\_Analysis.html](https://learn.adacore.com/courses/intro-to-spark/chapters/02_Flow_Analysis.html)  
9. SPARK 2014 Rationale: Ghost Code \- AdaCore, accessed March 27, 2026, [https://www.adacore.com/blog/spark-2014-rationale-ghost-code](https://www.adacore.com/blog/spark-2014-rationale-ghost-code)  
10. Verifying LLM-Generated Code in the Context of Software Verification with Ada/SPARK, accessed March 27, 2026, [https://arxiv.org/html/2502.07728v1](https://arxiv.org/html/2502.07728v1)  
11. A Formalization of Core Why3 in Coq \- Sandia National Laboratories, accessed March 27, 2026, [https://www.sandia.gov/app/uploads/sites/222/2024/02/cohen\_popl24\_why3.pdf](https://www.sandia.gov/app/uploads/sites/222/2024/02/cohen_popl24_why3.pdf)  
12. Dafny Documentation, accessed March 27, 2026, [https://dafny.org/dafny/DafnyRef/DafnyRef](https://dafny.org/dafny/DafnyRef/DafnyRef)  
13. SPARK User's Guide \- Documentation, accessed March 27, 2026, [https://docs.adacore.com/spark2014-docs/pdf/spark2014\_ug.pdf](https://docs.adacore.com/spark2014-docs/pdf/spark2014_ug.pdf)  
14. SPARK Proof Manual \- Documentation, accessed March 27, 2026, [https://docs.adacore.com/sparkdocs-docs/Proof\_Manual.htm](https://docs.adacore.com/sparkdocs-docs/Proof_Manual.htm)  
15. SPARK: An “Intensive Overview” \- SIGAda, accessed March 27, 2026, [http://www.sigada.org/conf/sigada2004/SIGAda2004-CDROM/SIGAda2004-Tutorials/SF2\_Chapman.pdf](http://www.sigada.org/conf/sigada2004/SIGAda2004-CDROM/SIGAda2004-Tutorials/SF2_Chapman.pdf)  
16. Development Logs | AdaCore, accessed March 27, 2026, [https://www.adacore.com/devlog](https://www.adacore.com/devlog)  
17. ADA USER JOURNAL, accessed March 27, 2026, [https://www.ada-europe.org/archive/auj/auj-42-2-news.pdf](https://www.ada-europe.org/archive/auj/auj-42-2-news.pdf)  
18. SIMPAL: A compositional reasoning framework for imperative programs by Lucas George Wagner A thesis submitted to the graduate fa, accessed March 27, 2026, [https://dr.lib.iastate.edu/bitstreams/6d906b1c-45d9-4e01-9fe7-e34bf1ace5a9/download](https://dr.lib.iastate.edu/bitstreams/6d906b1c-45d9-4e01-9fe7-e34bf1ace5a9/download)
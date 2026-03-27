# Prompt für AI-Analyse: Ada Forth Interpreter mit SPARK-Validierung

## Kontext
Ich habe ein Ada-Forth-Interpreter-Projekt mit formaler Validierung durch SPARK. Das Projekt enthält:
- Ada-Quellcode (.ads/.adb Dateien) in src/
- SPARK-Beweisdateien (.cswi, .bexch) in obj/
- Projektdokumentation und Spezifikationen
- Build-Skripte und Konfigurationsdateien

## Hauptaufgabe

Bitte erkläre mir auf Deutsch, wie formale Quellcode-Validierung in diesem spezifischen Projekt funktioniert. Analysiere den bereitgestellten Kontext und gib eine umfassende Erklärung.

## Spezifische Anforderungen

### 1. Formale Validierung erklärt
- Wie funktioniert SPARK in diesem Projekt?
- Was sind Proof Obligations und wie werden sie generiert?
- Welche Arten von Verifikationen werden durchgeführt?
- Wie interpretiert man die .cswi und .bexch Dateien?
- Was bedeuten die verschiedenen Beweisergebnisse?

### 2. Technischer Glossar (Deutsch)
Erkläre die folgenden Begriffe im Kontext dieses Projekts:
- SPARK
- Proof Obligation
- Counterexample
- Verification Condition
- Assertion
- Precondition/Postcondition
- Invariant
- Ghost Code
- Abstract State
- Flow Analysis
- Data Dependencies
- Information Flow
- GNATprove
- Why3

### 3. Projekt-Design-Analyse
Diskutiere die folgenden Design-Entscheidungen:
- Warum wurde Ada mit SPARK für einen Forth-Interpreter gewählt?
- Welche Sicherheits- oder Zuverlässigkeitsanforderungen könnten hinter dieser Wahl stecken?
- Wie werden die formalen Methoden in der Architektur genutzt?
- Welche Kompromisse wurden zwischen Performance und Verifizierbarkeit gemacht?
- Wie ist die Modulstruktur für die formale Verifikation optimiert?
- Welche Bereiche des Interpreters werden besonders stark verifiziert?

### 4. Praktische Analyse
- Welche Proof Obligations sind erfolgreich bewiesen?
- Wo gibt es Counterexamples und was bedeuten diese?
- Wie vollständig ist die formale Verifikation?
- Welche Bereiche könnten noch verifiziert werden?
- Wie nützlich sind die aktuellen Beweise für die Code-Qualität?

### 5. Lernziele
Ich möchte verstehen:
- Wie man formale Methoden in praktischen Projekten anwendet
- Wie man SPARK-Beweisergebnisse interpretiert
- Wie man Design-Entscheidungen basierend auf Verifizierungsanforderungen trifft
- Wie man die Balance zwischen Entwicklungsaufwand und Sicherheitsgewinn findet

## Erwartete Ausgabe

Bitte strukturiere deine Antwort wie folgt:

1. **Einleitung**: Kurze Zusammenfassung des Projekts und der formalen Validierung
2. **Technischer Glossar**: Alphabetisch geordnete Erklärungen mit Beispielen aus dem Code
3. **Formale Validierung im Detail**: Schritt-für-Schritt Erklärung des Prozesses
4. **Design-Analyse**: Diskussion der Architektur-Entscheidungen
5. **Praktische Ergebnisse**: Analyse der konkreten Beweisergebnisse
6. **Fazit**: Zusammenfassung der Erkenntnisse und Empfehlungen

## Sprachanweisungen
- Antworte vollständig auf Deutsch
- Verwende präzise technische Terminologie
- Gib konkrete Code-Beispiele aus dem Projekt
- Sei detailliert aber verständlich
- Fokussiere auf praktische Anwendbarkeit

## Zusätzliche Hinweise
Der Kontext enthält alle relevanten Quelldateien, Beweisdateien und Dokumentation. Bitte analysiere diese gründlich und beziehe dich auf spezifische Dateien und Code-Stellen, wo immer es sinnvoll ist.

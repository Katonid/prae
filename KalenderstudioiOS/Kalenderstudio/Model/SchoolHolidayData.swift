import Foundation

/// Schulferien aller 16 Bundesländer, fest eingebaut.
///
/// Quelle: OpenHolidays API (openholidaysapi.org), abgerufen am 09.10.2026,
/// Schuljahre 2025/26 bis 2028/29. Für Mecklenburg-Vorpommern gelten die
/// Termine der allgemeinbildenden Schulen. Neuere Jahre lädt die App bei
/// Bedarf nach (`SchoolHolidayService`), das Ergebnis wird gespeichert.
///
/// Format je Zeile: Land|Beginn|Ende|Name — Beginn und Ende einschließlich.
enum SchoolHolidayData {
    static let embedded = """
BB|2025-12-22|2026-01-02|Weihnachtsferien
BB|2026-02-02|2026-02-07|Winterferien
BB|2026-03-30|2026-04-10|Osterferien
BB|2026-05-15|2026-05-15|Variabler Ferientag
BB|2026-05-26|2026-05-26|Pfingstferien
BB|2026-07-09|2026-08-22|Sommerferien
BB|2026-10-19|2026-10-30|Herbstferien
BB|2026-12-23|2027-01-02|Weihnachtsferien
BB|2027-02-01|2027-02-06|Winterferien
BB|2027-03-22|2027-04-03|Osterferien
BB|2027-05-07|2027-05-07|Variabler Ferientag
BB|2027-05-18|2027-05-18|Pfingstferien
BB|2027-07-01|2027-08-14|Sommerferien
BB|2027-10-11|2027-10-23|Herbstferien
BB|2027-12-23|2027-12-31|Weihnachtsferien
BB|2028-01-31|2028-02-05|Winterferien
BB|2028-04-10|2028-04-22|Osterferien
BB|2028-05-26|2028-05-26|Variabler Ferientag
BB|2028-06-29|2028-08-12|Sommerferien
BB|2028-10-02|2028-10-14|Herbstferien
BB|2028-10-30|2028-10-30|Variabler Ferientag
BB|2028-12-22|2029-01-02|Weihnachtsferien
BE|2025-12-22|2026-01-02|Weihnachtsferien
BE|2026-02-02|2026-02-07|Winterferien
BE|2026-03-30|2026-04-10|Osterferien
BE|2026-05-15|2026-05-15|Unterrichtsfreier Tag
BE|2026-05-26|2026-05-26|Pfingstferien
BE|2026-07-09|2026-08-22|Sommerferien
BE|2026-10-19|2026-10-31|Herbstferien
BE|2026-12-23|2027-01-02|Weihnachtsferien
BE|2027-02-01|2027-02-06|Winterferien
BE|2027-03-22|2027-04-02|Osterferien
BE|2027-05-07|2027-05-07|Unterrichtsfreier Tag
BE|2027-05-18|2027-05-19|Pfingstferien
BE|2027-07-01|2027-08-14|Sommerferien
BE|2027-10-11|2027-10-23|Herbstferien
BE|2027-12-22|2027-12-31|Weihnachtsferien
BE|2028-01-31|2028-02-05|Winterferien
BE|2028-04-10|2028-04-22|Osterferien
BE|2028-05-26|2028-05-26|Unterrichtsfreier Tag
BE|2028-06-01|2028-06-02|Pfingstferien
BE|2028-07-01|2028-08-12|Sommerferien
BE|2028-10-02|2028-10-14|Herbstferien
BE|2028-12-22|2029-01-02|Weihnachtsferien
BW|2025-12-22|2026-01-05|Weihnachtsferien
BW|2026-03-30|2026-04-11|Osterferien
BW|2026-05-26|2026-06-05|Pfingstferien
BW|2026-07-30|2026-09-12|Sommerferien
BW|2026-10-26|2026-10-30|Herbstferien
BW|2026-10-31|2026-10-31|Reformationsfest
BW|2026-12-23|2027-01-09|Weihnachtsferien
BW|2027-03-25|2027-03-25|Gründonnerstag
BW|2027-03-30|2027-04-03|Osterferien
BW|2027-05-18|2027-05-29|Pfingstferien
BW|2027-07-29|2027-09-11|Sommerferien
BW|2027-11-02|2027-11-06|Herbstferien
BW|2027-12-23|2028-01-08|Weihnachtsferien
BW|2028-04-13|2028-04-13|Gründonnerstag
BW|2028-04-18|2028-04-22|Osterferien
BW|2028-06-06|2028-06-17|Pfingstferien
BW|2028-07-27|2028-09-09|Sommerferien
BW|2028-10-30|2028-11-03|Herbstferien
BW|2028-12-23|2029-01-05|Weihnachtsferien
BY|2025-12-22|2026-01-05|Weihnachtsferien
BY|2026-02-16|2026-02-20|Frühjahrsferien
BY|2026-03-30|2026-04-10|Osterferien
BY|2026-05-26|2026-06-05|Pfingstferien
BY|2026-08-03|2026-09-14|Sommerferien
BY|2026-11-02|2026-11-06|Herbstferien
BY|2026-11-18|2026-11-18|Buß- und Bettag
BY|2026-12-24|2027-01-08|Weihnachtsferien
BY|2027-02-08|2027-02-12|Frühjahrsferien
BY|2027-03-22|2027-04-02|Osterferien
BY|2027-05-18|2027-05-28|Pfingstferien
BY|2027-08-02|2027-09-13|Sommerferien
BY|2027-11-02|2027-11-05|Herbstferien
BY|2027-11-17|2027-11-17|Buß- und Bettag
BY|2027-12-24|2028-01-07|Weihnachtsferien
BY|2028-02-28|2028-03-03|Frühjahrsferien
BY|2028-04-10|2028-04-21|Osterferien
BY|2028-06-06|2028-06-16|Pfingstferien
BY|2028-07-31|2028-09-11|Sommerferien
BY|2028-10-30|2028-11-03|Herbstferien
BY|2028-11-22|2028-11-22|Buß- und Bettag
BY|2028-12-23|2029-01-05|Weihnachtsferien
HB|2025-12-22|2026-01-05|Weihnachtsferien
HB|2026-02-02|2026-02-03|Halbjahresferien
HB|2026-03-23|2026-04-07|Osterferien
HB|2026-05-15|2026-05-15|Tag nach Himmelfahrt
HB|2026-05-26|2026-05-26|Pfingstferien
HB|2026-07-02|2026-08-12|Sommerferien
HB|2026-10-12|2026-10-24|Herbstferien
HB|2026-12-23|2027-01-09|Weihnachtsferien
HB|2027-02-01|2027-02-02|Halbjahresferien
HB|2027-03-22|2027-04-03|Osterferien
HB|2027-05-07|2027-05-07|Tag nach Himmelfahrt
HB|2027-05-18|2027-05-18|Pfingstferien
HB|2027-07-08|2027-08-18|Sommerferien
HB|2027-10-18|2027-10-30|Herbstferien
HB|2027-12-23|2028-01-08|Weihnachtsferien
HB|2028-01-31|2028-02-01|Halbjahresferien
HB|2028-04-10|2028-04-22|Osterferien
HB|2028-05-26|2028-05-26|Tag nach Himmelfahrt
HB|2028-06-06|2028-06-06|Pfingstferien
HB|2028-07-20|2028-08-30|Sommerferien
HB|2028-10-02|2028-10-02|Tag vor dem 3. Oktober
HB|2028-10-23|2028-11-04|Herbstferien
HB|2028-12-27|2029-01-06|Weihnachtsferien
HE|2025-12-22|2026-01-10|Weihnachtsferien
HE|2026-03-30|2026-04-10|Osterferien
HE|2026-06-29|2026-08-07|Sommerferien
HE|2026-10-05|2026-10-17|Herbstferien
HE|2026-12-23|2027-01-12|Weihnachtsferien
HE|2027-03-22|2027-04-02|Osterferien
HE|2027-06-28|2027-08-06|Sommerferien
HE|2027-10-04|2027-10-16|Herbstferien
HE|2027-12-23|2028-01-11|Weihnachtsferien
HE|2028-04-03|2028-04-14|Osterferien
HE|2028-07-03|2028-08-11|Sommerferien
HE|2028-10-09|2028-10-20|Herbstferien
HE|2028-12-27|2029-01-12|Weihnachtsferien
HH|2025-12-17|2026-01-02|Weihnachtsferien
HH|2026-01-30|2026-01-30|Halbjahrespause
HH|2026-03-02|2026-03-13|Frühjahrsferien
HH|2026-05-11|2026-05-15|Pfingstferien
HH|2026-07-09|2026-08-19|Sommerferien
HH|2026-10-19|2026-10-30|Herbstferien
HH|2026-12-21|2027-01-01|Weihnachtsferien
HH|2027-01-29|2027-01-29|Halbjahrespause
HH|2027-03-01|2027-03-12|Frühjahrsferien
HH|2027-05-07|2027-05-14|Pfingstferien
HH|2027-07-01|2027-08-11|Sommerferien
HH|2027-10-11|2027-10-22|Herbstferien
HH|2027-12-20|2027-12-31|Weihnachtsferien
HH|2028-01-28|2028-01-28|Halbjahrespause
HH|2028-03-06|2028-03-17|Frühjahrsferien
HH|2028-05-22|2028-05-26|Pfingstferien
HH|2028-07-03|2028-08-11|Sommerferien
HH|2028-10-02|2028-10-13|Herbstferien
HH|2028-10-30|2028-10-30|Brückentag
HH|2028-12-18|2028-12-29|Weihnachtsferien
MV|2025-12-20|2026-01-03|Weihnachtsferien
MV|2026-02-09|2026-02-20|Winterferien
MV|2026-03-30|2026-04-08|Osterferien
MV|2026-05-15|2026-05-15|Zusätzlicher Ferientag
MV|2026-05-22|2026-05-26|Pfingstferien
MV|2026-07-13|2026-08-22|Sommerferien
MV|2026-10-15|2026-10-24|Herbstferien
MV|2026-11-26|2026-11-26|Zusätzlicher Ferientag
MV|2026-11-27|2026-11-27|Zusätzlicher Ferientag
MV|2026-12-21|2027-01-02|Weihnachtsferien
MV|2027-02-08|2027-02-19|Winterferien
MV|2027-03-24|2027-04-02|Osterferien
MV|2027-05-07|2027-05-07|Zusätzlicher Ferientag
MV|2027-05-14|2027-05-18|Pfingstferien
MV|2027-07-05|2027-08-14|Sommerferien
MV|2027-10-14|2027-10-23|Herbstferien
MV|2027-11-25|2027-11-25|Zusätzlicher Ferientag
MV|2027-11-26|2027-11-26|Zusätzlicher Ferientag
MV|2027-12-22|2028-01-04|Weihnachtsferien
MV|2028-02-05|2028-02-17|Winterferien
MV|2028-02-18|2028-02-18|Schulfrei
MV|2028-04-12|2028-04-21|Osterferien
MV|2028-05-26|2028-05-26|Zusätzlicher Ferientag
MV|2028-06-02|2028-06-06|Pfingstferien
MV|2028-06-26|2028-08-05|Sommerferien
MV|2028-10-02|2028-10-02|Zusätzlicher Ferientag
MV|2028-10-23|2028-10-28|Herbstferien
MV|2028-10-30|2028-10-30|Zusätzlicher Ferientag
MV|2028-12-22|2029-01-02|Weihnachtsferien
NI|2025-12-22|2026-01-05|Weihnachtsferien
NI|2026-02-02|2026-02-03|Halbjahresferien
NI|2026-03-23|2026-04-07|Osterferien
NI|2026-05-15|2026-05-15|Tag nach Himmelfahrt
NI|2026-05-26|2026-05-26|Pfingstferien
NI|2026-07-02|2026-08-12|Sommerferien
NI|2026-10-12|2026-10-24|Herbstferien
NI|2026-12-23|2027-01-09|Weihnachtsferien
NI|2027-02-01|2027-02-02|Halbjahresferien
NI|2027-03-22|2027-04-03|Osterferien
NI|2027-05-07|2027-05-07|Tag nach Himmelfahrt
NI|2027-05-18|2027-05-18|Pfingstferien
NI|2027-07-08|2027-08-18|Sommerferien
NI|2027-10-16|2027-10-30|Herbstferien
NI|2027-12-23|2028-01-08|Weihnachtsferien
NI|2028-01-31|2028-02-01|Halbjahresferien
NI|2028-04-10|2028-04-22|Osterferien
NI|2028-05-26|2028-05-26|Tag nach Himmelfahrt
NI|2028-06-06|2028-06-06|Pfingstferien
NI|2028-07-20|2028-08-30|Sommerferien
NI|2028-10-02|2028-10-02|Tag vor dem 3. Oktober
NI|2028-10-23|2028-11-04|Herbstferien
NI|2028-12-27|2029-01-06|Weihnachtsferien
NW|2025-12-22|2026-01-06|Weihnachtsferien
NW|2026-03-30|2026-04-11|Osterferien
NW|2026-05-26|2026-05-26|Pfingstferien
NW|2026-07-20|2026-09-01|Sommerferien
NW|2026-10-17|2026-10-31|Herbstferien
NW|2026-12-23|2027-01-06|Weihnachtsferien
NW|2027-03-22|2027-04-03|Osterferien
NW|2027-05-18|2027-05-18|Pfingstferien
NW|2027-07-19|2027-08-31|Sommerferien
NW|2027-10-23|2027-11-06|Herbstferien
NW|2027-12-24|2028-01-08|Weihnachtsferien
NW|2028-04-10|2028-04-22|Osterferien
NW|2028-07-10|2028-08-22|Sommerferien
NW|2028-10-23|2028-11-04|Herbstferien
NW|2028-12-21|2029-01-05|Weihnachtsferien
RP|2025-12-22|2026-01-07|Weihnachtsferien
RP|2026-03-30|2026-04-10|Osterferien
RP|2026-06-29|2026-08-07|Sommerferien
RP|2026-10-05|2026-10-16|Herbstferien
RP|2026-12-23|2027-01-08|Weihnachtsferien
RP|2027-03-22|2027-04-02|Osterferien
RP|2027-06-28|2027-08-06|Sommerferien
RP|2027-10-04|2027-10-15|Herbstferien
RP|2027-12-23|2028-01-07|Weihnachtsferien
RP|2028-04-10|2028-04-21|Osterferien
RP|2028-07-03|2028-08-11|Sommerferien
RP|2028-10-09|2028-10-20|Herbstferien
RP|2028-12-21|2029-01-08|Weihnachtsferien
SH|2025-12-19|2026-01-06|Weihnachtsferien
SH|2026-03-26|2026-04-10|Osterferien
SH|2026-05-15|2026-05-15|Himmelfahrt
SH|2026-07-04|2026-08-08|Sommerferien
SH|2026-07-04|2026-08-15|Sommerferien
SH|2026-10-05|2026-10-24|Herbstferien
SH|2026-10-12|2026-10-24|Herbstferien
SH|2026-12-21|2027-01-06|Weihnachtsferien
SH|2027-03-30|2027-04-10|Osterferien
SH|2027-05-07|2027-05-07|Himmelfahrt
SH|2027-07-03|2027-08-07|Sommerferien
SH|2027-07-03|2027-08-14|Sommerferien
SH|2027-10-04|2027-10-23|Herbstferien
SH|2027-10-11|2027-10-23|Herbstferien
SH|2027-12-23|2028-01-08|Weihnachtsferien
SH|2028-04-03|2028-04-15|Osterferien
SH|2028-05-26|2028-05-26|Himmelfahrt
SH|2028-06-24|2028-07-28|Sommerferien
SH|2028-06-24|2028-08-04|Sommerferien
SH|2028-10-09|2028-10-30|Herbstferien
SH|2028-10-16|2028-10-30|Herbstferien
SH|2028-12-21|2029-01-05|Weihnachtsferien
SL|2025-12-22|2026-01-02|Weihnachtsferien
SL|2026-02-16|2026-02-20|Fastnachtsferien
SL|2026-04-07|2026-04-17|Osterferien
SL|2026-06-29|2026-08-07|Sommerferien
SL|2026-10-05|2026-10-16|Herbstferien
SL|2026-12-21|2026-12-31|Weihnachtsferien
SL|2027-02-08|2027-02-12|Fastnachtsferien
SL|2027-03-30|2027-04-09|Osterferien
SL|2027-06-28|2027-08-06|Sommerferien
SL|2027-10-04|2027-10-15|Herbstferien
SL|2027-12-20|2027-12-31|Weihnachtsferien
SL|2028-02-21|2028-02-29|Fastnachtsferien
SL|2028-04-12|2028-04-21|Osterferien
SL|2028-07-03|2028-08-11|Sommerferien
SL|2028-10-09|2028-10-20|Herbstferien
SL|2028-12-20|2029-01-02|Weihnachtsferien
SN|2025-12-22|2026-01-02|Weihnachtsferien
SN|2026-02-09|2026-02-21|Winterferien
SN|2026-04-03|2026-04-10|Osterferien
SN|2026-05-15|2026-05-15|Unterrichtsfreier Tag
SN|2026-07-04|2026-08-14|Sommerferien
SN|2026-10-12|2026-10-24|Herbstferien
SN|2026-12-23|2027-01-02|Weihnachtsferien
SN|2027-02-08|2027-02-19|Winterferien
SN|2027-03-26|2027-04-02|Osterferien
SN|2027-05-07|2027-05-07|Unterrichtsfreier Tag
SN|2027-05-15|2027-05-18|Pfingstferien
SN|2027-07-10|2027-08-20|Sommerferien
SN|2027-10-11|2027-10-23|Herbstferien
SN|2027-12-23|2028-01-01|Weihnachtsferien
SN|2028-02-14|2028-02-26|Winterferien
SN|2028-04-14|2028-04-22|Osterferien
SN|2028-05-26|2028-05-26|Unterrichtsfreier Tag
SN|2028-07-22|2028-09-01|Sommerferien
SN|2028-10-23|2028-11-03|Herbstferien
SN|2028-12-23|2029-01-03|Weihnachtsferien
ST|2025-12-22|2026-01-05|Weihnachtsferien
ST|2026-01-31|2026-02-06|Winterferien
ST|2026-03-30|2026-04-04|Osterferien
ST|2026-05-26|2026-05-29|Pfingstferien
ST|2026-07-04|2026-08-14|Sommerferien
ST|2026-10-19|2026-10-30|Herbstferien
ST|2026-12-21|2027-01-02|Weihnachtsferien
ST|2027-02-01|2027-02-06|Winterferien
ST|2027-03-22|2027-03-27|Osterferien
ST|2027-05-15|2027-05-22|Pfingstferien
ST|2027-07-10|2027-08-20|Sommerferien
ST|2027-10-18|2027-10-23|Herbstferien
ST|2027-12-20|2027-12-31|Weihnachtsferien
ST|2028-02-07|2028-02-12|Winterferien
ST|2028-04-10|2028-04-22|Osterferien
ST|2028-06-03|2028-06-10|Pfingstferien
ST|2028-07-22|2028-09-01|Sommerferien
ST|2028-10-02|2028-10-02|Ferientag
ST|2028-10-30|2028-11-03|Herbstferien
ST|2028-12-21|2029-01-02|Weihnachtsferien
TH|2025-12-22|2026-01-03|Weihnachtsferien
TH|2026-02-16|2026-02-21|Winterferien
TH|2026-04-07|2026-04-17|Osterferien
TH|2026-05-15|2026-05-15|Schulfreier Tag
TH|2026-07-04|2026-08-14|Sommerferien
TH|2026-10-12|2026-10-24|Herbstferien
TH|2026-12-23|2027-01-02|Weihnachtsferien
TH|2027-02-01|2027-02-06|Winterferien
TH|2027-03-22|2027-04-03|Osterferien
TH|2027-05-07|2027-05-07|Schulfreier Tag
TH|2027-07-10|2027-08-20|Sommerferien
TH|2027-10-09|2027-10-23|Herbstferien
TH|2027-12-23|2027-12-31|Weihnachtsferien
TH|2028-02-07|2028-02-12|Winterferien
TH|2028-04-03|2028-04-15|Osterferien
TH|2028-05-26|2028-05-26|Schulfreier Tag
TH|2028-07-22|2028-09-01|Sommerferien
TH|2028-10-23|2028-11-03|Herbstferien
TH|2028-12-23|2029-01-05|Weihnachtsferien
"""
}

/// Tamaños de letra de la app (D-01). Todo `fontSize` en `presentation/`
/// sale de aquí; no se escriben números sueltos.
///
/// Escala de lectura, ocho pasos de 9 a 22:
///
/// | Token      | px | Para qué                                        |
/// |------------|----|-------------------------------------------------|
/// | `micro`    |  9 | sellos y adornos; nada que haya que leer (D-02)  |
/// | `caption`  | 10 | etiquetas en mayúsculas, metadatos, contadores  |
/// | `label`    | 11 | texto secundario, chips, subtítulos de fila     |
/// | `body`     | 12 | cuerpo                                          |
/// | `bodyLg`   | 13 | cuerpo destacado, nombres en listas             |
/// | `title`    | 14 | títulos de tarjeta y de ítem                    |
/// | `heading`  | 16 | títulos de sheet y de bloque                    |
/// | `headline` | 22 | títulos de pantalla interior y cifras           |
///
/// Display, fuera de la lectura corrida:
///
/// | Token     | px | Para qué                                  |
/// |-----------|----|-------------------------------------------|
/// | `display` | 26 | cabecera de pestaña (`INICIO // 01`)      |
/// | `hero`    | 40 | cifra protagonista (nivel, ritmo)          |
/// | `giant`   | 64 | glifo decorativo (kanji de capítulo)       |
///
/// Quedan fuera, a propósito:
/// - tamaños proporcionales a su contenedor (`size * 0.42` en avatares,
///   máscaras, lunas): escalan con la pieza, no con la escala;
/// - las cifras de póster de Wrapped por encima de `display` y el lienzo
///   de exportación de la historia (`wrapped/story_image.dart`), que mide
///   en píxeles de una imagen de 1080 de ancho.
abstract final class AppFontSize {
  static const double micro = 9;
  static const double caption = 10;
  static const double label = 11;
  static const double body = 12;
  static const double bodyLg = 13;
  static const double title = 14;
  static const double heading = 16;
  static const double headline = 22;

  static const double display = 26;
  static const double hero = 40;
  static const double giant = 64;
}

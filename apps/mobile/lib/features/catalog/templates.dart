/// What the onboarding "giro" changes in the catalog: suggested categories, product-level fields
/// and the axes that multiply into variants (size × color for clothing).
class VariantAxis {
  const VariantAxis(this.key, this.label, this.options);

  final String key;
  final String label;
  final List<String> options;
}

class CatalogTemplate {
  const CatalogTemplate({this.categories = const [], this.fields = const [], this.axes = const []});

  final List<String> categories;

  /// Product-level text fields stored in products.attrs, e.g. brand.
  final List<({String key, String label})> fields;
  final List<VariantAxis> axes;
}

const catalogTemplates = <String, CatalogTemplate>{
  'clothing': CatalogTemplate(
    categories: ['Playeras', 'Camisas', 'Pantalones', 'Vestidos', 'Sudaderas', 'Calzado', 'Accesorios'],
    axes: [
      VariantAxis('talla', 'Tallas', ['CH', 'M', 'G', 'EG']),
      VariantAxis('color', 'Colores', ['Negro', 'Blanco', 'Gris', 'Azul', 'Rojo', 'Beige']),
    ],
  ),
  'food': CatalogTemplate(
    categories: ['Platillos', 'Antojitos', 'Bebidas', 'Postres', 'Combos'],
    axes: [VariantAxis('tamano', 'Tamaños', ['Chico', 'Mediano', 'Grande'])],
  ),
  'tech': CatalogTemplate(
    categories: ['Celulares', 'Accesorios', 'Audio', 'Computación', 'Cables y cargadores'],
    fields: [(key: 'marca', label: 'Marca'), (key: 'modelo', label: 'Modelo')],
    axes: [VariantAxis('color', 'Colores', ['Negro', 'Blanco', 'Azul', 'Rojo'])],
  ),
  'other': CatalogTemplate(categories: ['General']),
};

CatalogTemplate templateFor(String? businessType) => catalogTemplates[businessType] ?? catalogTemplates['other']!;

/// Cartesian product of the chosen values. Axes with nothing chosen are skipped;
/// nothing chosen at all gives one plain variant.
List<Map<String, String>> expandVariants(Map<String, List<String>> chosen) {
  var combos = <Map<String, String>>[{}];
  for (final MapEntry(key: axis, value: values) in chosen.entries) {
    if (values.isEmpty) continue;
    combos = [
      for (final combo in combos)
        for (final value in values) {...combo, axis: value},
    ];
  }
  return combos;
}

/// "Talla M, Negro" style label for a variant.
String variantLabel(Map<String, String> attrs) => attrs.values.join(', ');

import 'package:cyna_mobile/screens/catalog_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildCatalogSearchPath encode les filtres avances', () {
    final path = buildCatalogSearchPath(
      query: 'SOC avance',
      mode: 'exact',
      sort: 'price_asc',
      minPrice: '10.5',
      maxPrice: '99',
      inStockOnly: true,
    );
    final uri = Uri.parse(path);

    expect(uri.path, '/search');
    expect(uri.queryParameters['q'], 'SOC avance');
    expect(uri.queryParameters['mode'], 'exact');
    expect(uri.queryParameters['sort'], 'price_asc');
    expect(uri.queryParameters['minPrice'], '10.5');
    expect(uri.queryParameters['maxPrice'], '99');
    expect(uri.queryParameters['inStock'], '1');
  });

  test('buildCatalogSearchPath omet les filtres vides', () {
    final uri = Uri.parse(buildCatalogSearchPath(
      query: '',
      mode: 'contains',
      sort: 'newest',
    ));

    expect(uri.queryParameters, {'sort': 'newest'});
  });
}

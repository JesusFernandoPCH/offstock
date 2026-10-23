import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class VariantRow {
  const VariantRow({required this.id, required this.attrs, required this.priceCents, required this.onHand, this.barcode});

  final String id;
  final Map<String, String> attrs;
  final int priceCents;
  final int onHand;
  final String? barcode;
}

class CatalogItem {
  const CatalogItem({
    required this.productId,
    required this.name,
    required this.variants,
    this.category,
    this.photoUrl,
  });

  final String productId;
  final String name;
  final String? category;
  final String? photoUrl;
  final List<VariantRow> variants;

  int get stock => variants.fold(0, (sum, v) => sum + v.onHand);
  int get minPrice => variants.map((v) => v.priceCents).reduce((a, b) => a < b ? a : b);
}

/// What the product form produces; mirrors create_product's arguments.
class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.variants,
    this.category,
    this.attrs = const {},
    this.photo,
  });

  final String name;
  final String? category;
  final Map<String, String> attrs;
  final Uint8List? photo;
  final List<({Map<String, String> attrs, int priceCents, int? costCents, int stock, String? barcode})> variants;
}

/// The scanned code already belongs to another variant of this business.
class DuplicateBarcodeException implements Exception {}

class CatalogRepo {
  CatalogRepo(this.db, this.businessId);

  final SupabaseClient db;
  final String businessId;

  static const _bucket = 'product-photos';

  Future<List<CatalogItem>> load() async {
    final products = await db
        .from('products')
        .select('id, name, category, photo_path, variants(id, attrs, price_cents, barcode, active)')
        .eq('business_id', businessId)
        .eq('active', true)
        .order('name');
    final stockRows = await db.from('variant_stock').select('variant_id, on_hand').eq('business_id', businessId);
    final stock = {for (final r in stockRows) r['variant_id'] as String: r['on_hand'] as int};

    final paths = [for (final p in products) if (p['photo_path'] != null) p['photo_path'] as String];
    final urls = <String, String>{};
    if (paths.isNotEmpty) {
      for (final r in await db.storage.from(_bucket).createSignedUrlsResult(paths, 3600)) {
        if (r is SignedUrlSuccess) urls[r.path] = r.signedUrl; // a missing photo just shows the placeholder
      }
    }

    return [
      for (final p in products)
        if ((p['variants'] as List).any((v) => v['active'] == true))
          CatalogItem(
            productId: p['id'] as String,
            name: p['name'] as String,
            category: p['category'] as String?,
            photoUrl: urls[p['photo_path']],
            variants: [
              for (final v in p['variants'] as List)
                if (v['active'] == true)
                  VariantRow(
                    id: v['id'] as String,
                    attrs: Map<String, String>.from(v['attrs'] as Map),
                    priceCents: v['price_cents'] as int,
                    barcode: v['barcode'] as String?,
                    onHand: stock[v['id']] ?? 0,
                  ),
            ],
          ),
    ];
  }

  /// Product, variants, costs and initial stock commit together; the photo follows.
  /// If the photo upload fails the product still exists and can get a photo later.
  Future<void> create(ProductDraft d) async {
    final String productId;
    try {
      productId = await db.rpc('create_product', params: {
        'p_business': businessId,
        'p_name': d.name,
        'p_category': d.category,
        'p_attrs': d.attrs,
        'p_variants': [
          for (final v in d.variants)
            {'attrs': v.attrs, 'price_cents': v.priceCents, 'cost_cents': v.costCents, 'stock': v.stock, 'barcode': v.barcode},
        ],
      }) as String;
    } on PostgrestException catch (e) {
      if (e.code == '23505' && e.message.contains('barcode')) throw DuplicateBarcodeException();
      rethrow;
    }

    if (d.photo != null) {
      final path = '$businessId/$productId.jpg';
      await db.storage.from(_bucket).uploadBinary(
            path,
            d.photo!,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      await db.from('products').update({'photo_path': path}).eq('id', productId);
    }
  }
}

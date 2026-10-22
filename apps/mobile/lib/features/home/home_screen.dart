import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/gallery_screen.dart';
import '../auth/session.dart';
import '../catalog/catalog_repo.dart';
import '../catalog/catalog_screen.dart';
import '../catalog/product_form_screen.dart';
import '../catalog/templates.dart';

/// Signed-in shell: sell (placeholder until Phase 3) and catalog.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _repo = CatalogRepo(widget.session.db, widget.session.businessId!);
  int _tab = 0;

  static const _guideKey = 'guide_product_form_seen';

  Future<bool?> _addProduct() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return null;
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(
          template: templateFor(widget.session.businessType),
          showGuide: !(prefs.getBool(_guideKey) ?? false),
          onGuideSeen: () => prefs.setBool(_guideKey, true),
          onSave: _repo.create,
          takePhoto: () async {
            // ~1080px at 70% JPEG lands around 150–300 KB, well under the 1 MB bucket limit.
            final shot = await ImagePicker().pickImage(
              source: ImageSource.camera,
              maxWidth: 1080,
              maxHeight: 1080,
              imageQuality: 70,
            );
            return shot?.readAsBytes();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return Column(
      children: [
        Expanded(
          // The tab bar below already pads for the system bar; don't pad twice.
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: IndexedStack(
              index: _tab,
              children: [
                GalleryScreen(title: s.businessName!, onSignOut: s.signOut),
                CatalogScreen(
                  load: _repo.load,
                  onAdd: s.isOwner ? _addProduct : null,
                ),
              ],
            ),
          ),
        ),
        _TabBar(
          index: _tab,
          labels: const ['Vender', 'Catálogo'],
          onSelect: (i) => setState(() => _tab = i),
        ),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.index,
    required this.labels,
    required this.onSelect,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            spacing: 8,
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Pressable(
                    selected: i == index,
                    scale: 0.96,
                    onTap: () => onSelect(i),
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: i == index
                            ? c.accentText.withValues(alpha: 0.12)
                            : const Color(0x00000000),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        labels[i],
                        style: OffstockType.label.copyWith(
                          fontSize: 15,
                          color: i == index ? c.accentText : c.inkSoft,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

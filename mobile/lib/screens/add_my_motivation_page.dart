import 'package:flutter/material.dart';
import '../models/motivation.dart';
import '../services/user_motivation_service.dart';
import '../widgets/header_bar.dart';
import 'content_detail_page.dart';

/// Kullanıcının kendi motivasyon cümlesini eklediği sayfa.
class AddMyMotivationPage extends StatefulWidget {
  const AddMyMotivationPage({super.key});

  @override
  State<AddMyMotivationPage> createState() => _AddMyMotivationPageState();
}

class _AddMyMotivationPageState extends State<AddMyMotivationPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  int _selectedCategoryIndex = 0;
  static const _categories = ['Teknoloji', 'Sanat', 'Tarih', 'Bilim'];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Başlık gerekli');
      return;
    }
    if (body.isEmpty) {
      setState(() => _error = 'İçerik gerekli');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final category = _categories[_selectedCategoryIndex];
      final m = await UserMotivationService.add(title, body, category: category);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ContentDetailPage(item: m),
        ),
      );
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Kaydedilemedi: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          HeaderBar(
            title: 'İçerik Ekle',
            leading: SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
            trailing: const SizedBox.shrink(),
          ),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: InputDecoration(
                      hintText: 'Başlık (ör: Hedeflerim)',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF374151)),
                      ),
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bodyController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Motivasyon cümlenizi veya notunuzu yazın...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF374151)),
                      ),
                    ),
                    maxLines: 6,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Kategori',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_categories.length, (i) {
                      final selected = i == _selectedCategoryIndex;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategoryIndex = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF2094F3) : const Color(0xFF27272A),
                            borderRadius: BorderRadius.circular(9999),
                            border: selected ? null : Border.all(color: const Color(0xFF3F3F46)),
                          ),
                          child: Text(
                            _categories[i],
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      );
                    }),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2094F3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Kaydet ve Görüntüle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

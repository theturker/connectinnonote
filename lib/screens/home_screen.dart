import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/note_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/note.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../widgets/note_card.dart';
import 'add_note_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _searchController = TextEditingController();
  final NoteController _noteController = Get.find<NoteController>();
  final AuthController _authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _buildNotesList(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      title: Text(
        'Notlarım',
        style: AppTextStyles.heading2.copyWith(
          color: Colors.white,
        ),
      ),
      actions: [
        // Favori butonu
        Obx(() => IconButton(
          icon: Icon(
            _noteController.showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
            color: _noteController.showFavoritesOnly ? Colors.red : Colors.white,
          ),
          onPressed: () {
            _noteController.toggleFavoritesFilter();
          },
        )),
        // Çıkış butonu
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () {
            _authController.logout();
            Get.offAllNamed('/login');
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Favori filtresi durumu
          Obx(() {
            if (_noteController.showFavoritesOnly) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite, color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Sadece Favoriler',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _noteController.clearFavoritesFilter(),
                      child: const Icon(Icons.close, color: Colors.red, size: 16),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          // Arama çubuğu
          TextField(
            controller: _searchController,
            onChanged: (value) {
              _noteController.updateSearchQuery(value);
            },
            decoration: InputDecoration(
              hintText: 'Notlarda ara...',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textLight,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textSecondary,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _noteController.clearSearch();
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList() {
    return Obx(() {
      if (_noteController.isLoading) {
        return const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        );
      }

      final notes = _noteController.filteredNotes;
      
      if (notes.isEmpty) {
        return _buildEmptyState();
      }

      return FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NoteCard(
                  note: note,
                  onTap: () => _navigateToEditNote(note),
                  onFavorite: () => _noteController.toggleFavorite(note.id),
                  onDelete: () => _showDeleteDialog(note),
                ),
              );
            },
          ),
        ),
      );
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: const Icon(
                  Icons.note_add_outlined,
                  size: 60,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _noteController.searchQuery.isNotEmpty
                    ? 'Arama sonucu bulunamadı'
                    : _noteController.showFavoritesOnly
                        ? 'Favori not bulunamadı'
                        : 'Henüz not yok',
                style: AppTextStyles.heading3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _noteController.searchQuery.isNotEmpty
                    ? 'Farklı anahtar kelimeler deneyin'
                    : _noteController.showFavoritesOnly
                        ? 'Henüz favori not yok'
                        : 'İlk notunuzu eklemek için + butonuna basın',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (_noteController.searchQuery.isNotEmpty || _noteController.showFavoritesOnly) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_noteController.searchQuery.isNotEmpty)
                      ElevatedButton(
                        onPressed: () {
                          _searchController.clear();
                          _noteController.clearSearch();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Aramayı Temizle'),
                      ),
                    if (_noteController.searchQuery.isNotEmpty && _noteController.showFavoritesOnly)
                      const SizedBox(width: 8),
                    if (_noteController.showFavoritesOnly)
                      ElevatedButton(
                        onPressed: () {
                          _noteController.clearFavoritesFilter();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Favori Filtresini Kapat'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () => _navigateToAddNote(),
      backgroundColor: AppColors.primary,
      child: const Icon(
        Icons.add,
        color: Colors.white,
      ),
    );
  }

  void _navigateToAddNote() {
    Get.to(() => const AddNoteScreen());
  }

  void _navigateToEditNote(Note note) {
    Get.to(() => AddNoteScreen(note: note));
  }

  void _showDeleteDialog(Note note) {
    Get.dialog(
      AlertDialog(
        title: Text(
          'Notu Sil',
          style: AppTextStyles.heading3,
        ),
        content: Text(
          'Bu notu silmek istediğinizden emin misiniz?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'İptal',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _noteController.deleteNote(note.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

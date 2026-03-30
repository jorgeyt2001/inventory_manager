import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../models/location.dart';
import '../../providers/product_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/location_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/color_utils.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';
import 'stock_adjustment_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ProductProvider>().loadProducts();
    context.read<CategoryProvider>().loadCategories();
    context.read<LocationProvider>().loadLocations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToForm(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<ProductProvider>().setSearchQuery('');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                context.read<ProductProvider>().setSearchQuery(value);
              },
            ),
          ),
          _buildFilterRowFull(),
          _buildActiveFilterChips(),
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No hay productos',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _navigateToForm(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar Producto'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: provider.products.length,
                  itemBuilder: (context, index) {
                    final product = provider.products[index];
                    return _buildProductCard(product);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // Category filter
          Expanded(
            child: Consumer<CategoryProvider>(
              builder: (context, catProvider, _) {
                final productProvider = context.watch<ProductProvider>();
                return DropdownButtonFormField<int>(
                  value: productProvider.filterCategoryId,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('Todas')),
                    ...catProvider.categories.map<DropdownMenuItem<int>>((AppCategory cat) =>
                      DropdownMenuItem<int>(value: cat.id, child: Text(cat.name)),
                    ),
                  ],
                  onChanged: (value) {
                    context.read<ProductProvider>().setFilterCategory(value);
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          // Location filter
          Expanded(
            child: Consumer<LocationProvider>(
              builder: (context, locProvider, _) {
                final productProvider = context.watch<ProductProvider>();
                return DropdownButtonFormField<int>(
                  value: productProvider.filterLocationId,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Ubicación',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('Todas')),
                    ...locProvider.locations.map<DropdownMenuItem<int>>((AppLocation loc) =>
                      DropdownMenuItem<int>(value: loc.id, child: Text(loc.name)),
                    ),
                  ],
                  onChanged: (value) {
                    context.read<ProductProvider>().setFilterLocation(value);
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          // Sort button
          Consumer<ProductProvider>(
            builder: (context, provider, _) => IconButton(
              icon: Icon(
                Icons.sort,
                color: provider.sortBy != 'name' ? Theme.of(context).colorScheme.primary : null,
              ),
              tooltip: 'Ordenar',
              onPressed: () => _showSortSheet(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          // Color filter
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, provider, _) => DropdownButtonFormField<String>(
                value: provider.filterColor,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Todos')),
                  ...Product.coloresSelene.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (v) => context.read<ProductProvider>().setFilterColor(v),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Talla filter
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, provider, _) => DropdownButtonFormField<String>(
                value: provider.filterTalla,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Talla',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Todas')),
                  ...Product.tallasSelene.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                ],
                onChanged: (v) => context.read<ProductProvider>().setFilterTalla(v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Combined filter rows (first + second)
  // We show both rows in a Column wrapped inside a Column
  // But to keep the UI clean, put the color/talla filters in a second row below
  Widget _buildFilterRowFull() {
    return Column(
      children: [
        _buildFilterRow(),
        _buildSecondFilterRow(),
      ],
    );
  }

  Widget _buildActiveFilterChips() {
    return Consumer<ProductProvider>(
      builder: (context, provider, _) {
        final chips = <Widget>[];

        if (provider.filterColor != null) {
          chips.add(_buildFilterChip(
            'Color: ${provider.filterColor}',
            () => provider.setFilterColor(null),
          ));
        }
        if (provider.filterTalla != null) {
          chips.add(_buildFilterChip(
            'Talla: ${provider.filterTalla}',
            () => provider.setFilterTalla(null),
          ));
        }
        if (provider.sortBy != 'name') {
          chips.add(_buildFilterChip(
            'Orden: ${_sortLabel(provider.sortBy)}',
            () => provider.setSortBy('name'),
          ));
        }

        if (chips.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: chips),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onRemove,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  String _sortLabel(String sort) {
    switch (sort) {
      case 'price_asc': return 'Precio ↑';
      case 'price_desc': return 'Precio ↓';
      case 'stock_asc': return 'Stock ↑';
      case 'stock_desc': return 'Stock ↓';
      default: return 'Nombre';
    }
  }

  void _showSortSheet(BuildContext context) {
    final provider = context.read<ProductProvider>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Ordenar por', style: Theme.of(context).textTheme.titleMedium),
            ),
            ...[
              ('name', 'Nombre A-Z', Icons.sort_by_alpha),
              ('price_asc', 'Precio (menor primero)', Icons.arrow_upward),
              ('price_desc', 'Precio (mayor primero)', Icons.arrow_downward),
              ('stock_asc', 'Stock (menor primero)', Icons.arrow_upward),
              ('stock_desc', 'Stock (mayor primero)', Icons.arrow_downward),
            ].map((entry) => ListTile(
              leading: Icon(entry.$3),
              title: Text(entry.$2),
              selected: provider.sortBy == entry.$1,
              selectedColor: Theme.of(context).colorScheme.primary,
              onTap: () {
                provider.setSortBy(entry.$1);
                Navigator.pop(ctx);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final isLowStock = product.stock <= product.minStock;
    final hasMargin = product.cost > 0 && product.price > 0;
    final margin = hasMargin ? ((product.price - product.cost) / product.price * 100) : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isLowStock ? Colors.orange[100] : Colors.blue[100],
          child: Icon(
            Icons.inventory_2,
            color: isLowStock ? Colors.orange : Colors.blue,
          ),
        ),
        title: Text(product.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (product.category != 'General')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      product.category,
                      style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                    ),
                  ),
                if (product.locationName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal[200]!),
                    ),
                    child: Text(
                      product.locationName!,
                      style: TextStyle(fontSize: 11, color: Colors.teal[700]),
                    ),
                  ),
              ],
            ),
            if (product.color != null || product.talla != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    if (product.color != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple[200]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ColorUtils.colorDot(product.color, size: 10),
                            Text(
                              product.color!,
                              style: TextStyle(fontSize: 11, color: Colors.purple[700]),
                            ),
                          ],
                        ),
                      ),
                    if (product.talla != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.indigo[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.indigo[200]!),
                        ),
                        child: Text(
                          'Talla ${product.talla!}',
                          style: TextStyle(fontSize: 11, color: Colors.indigo[700]),
                        ),
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                Text(
                  AppFormatters.currency(product.price),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isLowStock ? Colors.orange[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Stock: ${product.stock}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isLowStock ? Colors.orange[800] : Colors.green[800],
                    ),
                  ),
                ),
                if (hasMargin) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: margin >= 40
                          ? Colors.green[100]
                          : margin >= 20
                              ? Colors.amber[100]
                              : Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${margin.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: margin >= 40
                            ? Colors.green[800]
                            : margin >= 20
                                ? Colors.amber[800]
                                : Colors.red[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Editar'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'stock',
              child: Row(
                children: [
                  Icon(Icons.tune),
                  SizedBox(width: 8),
                  Text('Ajustar stock'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Eliminar', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _navigateToForm(context, product: product);
            } else if (value == 'stock') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StockAdjustmentScreen(product: product),
                ),
              );
            } else if (value == 'delete') {
              _confirmDelete(context, product);
            }
          },
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
        ),
      ),
    );
  }

  void _navigateToForm(BuildContext context, {Product? product}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(product: product),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text('¿Estás seguro de eliminar "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              context.read<ProductProvider>().deleteProduct(product.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Producto eliminado')),
              );
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

}

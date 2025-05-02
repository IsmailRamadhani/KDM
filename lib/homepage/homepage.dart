import 'dart:typed_data';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:ta_project/itemModel/item_model.dart';
import 'package:ta_project/itemModel/database_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ta_project/auth/login.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DataBaseHelper _dbHelper = DataBaseHelper();
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _qtyController = TextEditingController();
  final _seriController = TextEditingController();
  final _brandController = TextEditingController();
  final _searchController = TextEditingController();

  List<Item> _items = [];
  List<Item> _filteredItems = [];
  Item? _itemToEdit;
  bool _isScanning = false;
  bool _isLoading = true;
  String _currentFilter = 'A-Z';

  final Map<String, Comparator<Item>> _sortOptions = {
    'A-Z': (a, b) => a.nama.compareTo(b.nama),
    'Z-A': (a, b) => b.nama.compareTo(a.nama),
    'QTY Terendah': (a, b) => a.qty.compareTo(b.qty),
    'QTY Tertinggi': (a, b) => b.qty.compareTo(a.qty),
  };

  @override
  void initState() {
    super.initState();
    _loadItems();
    _searchController.addListener(_searchItems);
  }

  Future<void> _generatePDF() async {
    try {
      final pdf = pw.Document();

      final itemsPerPage = 20;
      final totalPages = (_filteredItems.length / itemsPerPage).ceil();

      for (var page = 0; page < totalPages; page++) {
        final startIndex = page * itemsPerPage;
        final endIndex =
            (page + 1) * itemsPerPage > _filteredItems.length
                ? _filteredItems.length
                : (page + 1) * itemsPerPage;
        final pageItems = _filteredItems.sublist(startIndex, endIndex);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.all(20),
            build: (pw.Context context) {
              return pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Daftar Barang',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Karya Duta Electric',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.Text(
                        'Halaman ${page + 1}/$totalPages',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(thickness: 1),
                  pw.SizedBox(height: 15),

                  pw.TableHelper.fromTextArray(
                    context: context,
                    border: pw.TableBorder(
                      left: pw.BorderSide(width: 0.5),
                      right: pw.BorderSide(width: 0.5),
                      top: pw.BorderSide(width: 0.5),
                      bottom: pw.BorderSide(width: 0.5),
                      horizontalInside: pw.BorderSide(width: 0.3),
                      verticalInside: pw.BorderSide(width: 0.3),
                    ),
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                      color: PdfColors.white,
                    ),
                    headerDecoration: pw.BoxDecoration(
                      color: PdfColors.blue800,
                    ),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellPadding: pw.EdgeInsets.all(5),
                    headerAlignment: pw.Alignment.centerLeft,
                    columnWidths: {
                      0: pw.FlexColumnWidth(0.5),
                      1: pw.FlexColumnWidth(2),
                      2: pw.FlexColumnWidth(1),
                      3: pw.FlexColumnWidth(1.5),
                      4: pw.FlexColumnWidth(1.5),
                    },
                    headers: [
                      'No',
                      'Nama Barang',
                      'Qty',
                      'Nomor Seri',
                      'Brand',
                    ],
                    data:
                        pageItems.asMap().entries.map((entry) {
                          final index = entry.key + 1 + (page * itemsPerPage);
                          final item = entry.value;
                          return [
                            index.toString(),
                            item.nama,
                            item.qty.toString(),
                            item.seri,
                            item.brand,
                          ];
                        }).toList(),
                  ),

                  pw.SizedBox(height: 20),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'Dibuat pada: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "Gagal membuat PDF: ${e.toString()}");
    }
  }

  Future<void> _loadItems() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      _items = await _dbHelper.getItems();
      if (mounted) {
        setState(() {
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _editItem(Item item) {
    if (!mounted) return;
    setState(() {
      _itemToEdit = item;
      _namaController.text = item.nama;
      _qtyController.text = item.qty.toString();
      _seriController.text = item.seri;
      _brandController.text = item.brand;

      _showEditItemDialog();
    });
  }

  void _searchItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems =
          _items.where((item) {
            return item.nama.toLowerCase().contains(query) ||
                item.brand.toLowerCase().contains(query) ||
                item.seri.toLowerCase().contains(query) ||
                item.qty.toString().contains(query);
          }).toList();
      _applyFilter();
    });
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate() || !mounted) return;

    try {
      final item = Item(
        id: _itemToEdit?.id,
        nama: _namaController.text,
        qty: int.parse(_qtyController.text),
        seri: _seriController.text,
        brand: _brandController.text,
      );

      if (_itemToEdit == null) {
        await _dbHelper.insertItem(item);
      } else {
        await _dbHelper.updateItem(item);
      }
      await _refreshItemList();
      _clearForm();
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(msg: "Error: ${e.toString()}");
      }
    }
  }

  Future<void> _deleteItem(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Konfirmasi'),
            content: const Text('Apakah Anda yakin ingin menghapus item ini?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Batal',
                  style: GoogleFonts.lato(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      try {
        await _dbHelper.deleteItem(id);
        if (mounted) {
          await _refreshItemList();
          Fluttertoast.showToast(msg: "Item berhasil dihapus!");
        }
      } catch (e) {
        if (mounted) {
          Fluttertoast.showToast(msg: "Error: ${e.toString()}");
        }
      }
    }
  }

  Future<void> _refreshItemList() async {
    if (!mounted) return;
    List<Item> items = await _dbHelper.getItems();
    if (mounted) {
      setState(() {
        _items = items;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    final itemsToSort =
        _searchController.text.isEmpty ? _items : _filteredItems;
    _filteredItems = List.from(itemsToSort)
      ..sort(_sortOptions[_currentFilter]!);
  }

  void _changeFilter(String? newValue) {
    if (newValue != null) {
      setState(() {
        _currentFilter = newValue;
        _applyFilter();
      });
    }
  }

  String _generateSHA256(String input) {
    var bytes = utf8.encode(input);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _generateQRData(Item item) {
    final data = {
      'id': item.id?.toString() ?? '0',
      'nama': item.nama,
      'seri': item.seri,
      'brand': item.brand,
      'hash': _generateSHA256(
        '${item.id}${item.nama}${item.seri}${item.brand}',
      ),
      'timestamp': DateTime.now().toIso8601String(),
    };
    return jsonEncode(data);
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  void _startScanning() {
    setState(() => _isScanning = true);
  }

  void _stopScanning() {
    setState(() => _isScanning = false);
  }

  void _handleScannedQRCode(String qrData) {
    try {
      final data = jsonDecode(qrData);

      if (data['id'] == null ||
          data['nama'] == null ||
          data['seri'] == null ||
          data['brand'] == null) {
        throw FormatException('QR Code tidak mengandung data yang lengkap');
      }

      if (data['hash'] != null) {
        final expectedHash = _generateSHA256(
          '${data['id']}${data['nama']}${data['seri']}${data['brand']}',
        );
        if (data['hash'] != expectedHash) {
          throw FormatException('Data QR Code tidak valid (Hash Mismatch)');
        }
      }

      final item = Item(
        id: int.tryParse(data['id'].toString()) ?? 0,
        nama: data['nama'].toString(),
        qty: int.tryParse(data['qty']?.toString() ?? '0') ?? 0,
        seri: data['seri'].toString(),
        brand: data['brand'].toString(),
      );

      setState(() {
        _itemToEdit = item;
        _namaController.text = item.nama;
        _qtyController.text = item.qty.toString();
        _seriController.text = item.seri;
        _brandController.text = item.brand;
      });

      _stopScanning();
      Fluttertoast.showToast(msg: "Item siap diedit: ${item.nama}");
      _showEditItemDialog();
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
      if (_isScanning) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _clearForm() {
    _namaController.clear();
    _qtyController.clear();
    _seriController.clear();
    _brandController.clear();
    _itemToEdit = null;
  }

  void _showQRDialog(Item item) {
    final qrData = _generateQRData(item);
    final GlobalKey qrKey = GlobalKey();

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Detail Item',
                      style: GoogleFonts.lato(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 12),
                    RepaintBoundary(
                      key: qrKey,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Column(
                          children: [
                            Text(
                              item.nama,
                              style: GoogleFonts.lato(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.seri,
                              style: GoogleFonts.lato(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              child: QrImageView(
                                data: qrData,
                                size: 180,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildItemDetailTile('Nama', item.nama),
                    _buildItemDetailTile('Qty', item.qty.toString()),
                    _buildItemDetailTile('Seri', item.seri),
                    _buildItemDetailTile('Brand', item.brand),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Tutup',
                            style: GoogleFonts.lato(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: () async {
                            try {
                              final status = await Permission.storage.request();
                              if (!status.isGranted) {
                                Fluttertoast.showToast(
                                  msg: "Izin penyimpanan ditolak",
                                );
                                return;
                              }
                              RenderRepaintBoundary boundary =
                                  qrKey.currentContext!.findRenderObject()
                                      as RenderRepaintBoundary;
                              ui.Image image = await boundary.toImage(
                                pixelRatio: 3.0,
                              );
                              ByteData? byteData = await image.toByteData(
                                format: ui.ImageByteFormat.png,
                              );
                              Uint8List pngBytes =
                                  byteData!.buffer.asUint8List();

                              final result = await ImageGallerySaverPlus.saveImage(
                                pngBytes,
                                name:
                                    'qr_${item.nama}_${DateTime.now().millisecondsSinceEpoch}',
                                quality: 100,
                              );

                              if (result['isSuccess'] == true) {
                                Fluttertoast.showToast(
                                  msg: "QR Code berhasil diunduh!",
                                );
                              } else {
                                Fluttertoast.showToast(
                                  msg:
                                      "Gagal mengunduh: ${result['errorMessage']}",
                                );
                              }
                            } catch (e) {
                              Fluttertoast.showToast(
                                msg: "Error: ${e.toString()}",
                              );
                            }
                          },
                          child: Text(
                            'Download',
                            style: GoogleFonts.lato(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            backgroundColor: Colors.lightBlue,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _editItem(item);
                          },
                          child: Text(
                            'Edit',
                            style: GoogleFonts.lato(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildItemDetailTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.lato(fontWeight: FontWeight.bold),
            ),
          ),
          const Text(': '),
          Text(value),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    _clearForm();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 50),
            contentPadding: const EdgeInsets.all(20),
            title: Text(
              'Tambah Barang Baru',
              style: GoogleFonts.lato(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 1,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _namaController,
                        decoration: InputDecoration(
                          labelText: 'Nama Barang',
                          labelStyle: GoogleFonts.lato(fontSize: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Silakan masukkan nama item';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _qtyController,
                        decoration: InputDecoration(
                          labelText: 'QTY',
                          labelStyle: GoogleFonts.lato(fontSize: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Silakan masukkan quantity';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Quantity harus berupa angka';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _seriController,
                        decoration: InputDecoration(
                          labelText: 'Nomor Seri',
                          labelStyle: GoogleFonts.lato(fontSize: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Silakan masukkan nomor seri';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _brandController,
                        decoration: InputDecoration(
                          labelText: 'Brand',
                          labelStyle: GoogleFonts.lato(fontSize: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Silakan masukkan brand';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Batal',
                  style: GoogleFonts.lato(color: Colors.red),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    await _saveItem();
                    if (mounted) Navigator.pop(context);
                  }
                },
                child: Text(
                  'Simpan',
                  style: GoogleFonts.lato(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _showEditItemDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 50),
            contentPadding: const EdgeInsets.all(20),
            title: Text(
              'Edit Barang',
              style: GoogleFonts.lato(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 1,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _namaController,
                        decoration: InputDecoration(
                          labelText: 'Nama Barang',
                          labelStyle: GoogleFonts.lato(fontSize: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Silakan masukkan nama barang';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _qtyController,
                        decoration: InputDecoration(
                          labelText: 'QTY',
                          labelStyle: GoogleFonts.lato(fontSize: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Silakan masukkan quantity';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Quantity harus berupa angka';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _seriController,
                        decoration: InputDecoration(
                          labelText: 'Nomor Seri',
                          labelStyle: GoogleFonts.lato(fontSize: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Silakan masukkan nomor seri';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _brandController,
                        decoration: InputDecoration(
                          labelText: 'Brand',
                          labelStyle: GoogleFonts.lato(fontSize: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Silakan masukkan brand';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _clearForm();
                  Navigator.pop(context);
                },
                child: Text(
                  'Batal',
                  style: GoogleFonts.lato(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    await _saveItem();
                    if (mounted) Navigator.pop(context);
                  }
                },
                child: Text(
                  'Perbarui',
                  style: GoogleFonts.lato(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _qtyController.dispose();
    _seriController.dispose();
    _brandController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isScanning) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Pindai QR Code',
            style: GoogleFonts.lato(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _stopScanning,
          ),
        ),
        body: MobileScanner(
          controller: MobileScannerController(
            detectionSpeed: DetectionSpeed.normal,
            facing: CameraFacing.back,
            torchEnabled: false,
          ),
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                _handleScannedQRCode(barcode.rawValue!);
                break;
              }
            }
          },
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.lightBlue,
        onPressed: () {
          _clearForm();
          _showAddItemDialog();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      appBar: AppBar(
        title: Text(
          'Pendataan Barang',
          style: GoogleFonts.lato(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.lightBlue,
        actions: [
          PopupMenuButton<String>(
            color: Colors.white,
            icon: Icon(Icons.filter_alt),
            iconColor: Colors.white,
            onSelected: _changeFilter,
            itemBuilder:
                (context) =>
                    _sortOptions.keys.map((option) {
                      return PopupMenuItem<String>(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
          ),
          PopupMenuButton<String>(
            color: Colors.white,
            icon: const Icon(Icons.more_vert),
            iconColor: Colors.white,
            onSelected: (value) {
              if (value == 'scan') {
                _startScanning();
              } else if (value == 'pdf') {
                _generatePDF();
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder:
                (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'scan',
                    child: ListTile(
                      leading: Icon(Icons.qr_code_scanner),
                      title: Text('Pindai QR Code'),
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'pdf',
                    child: ListTile(
                      leading: Icon(Icons.picture_as_pdf),
                      title: Text('Ekspor ke PDF'),
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout),
                      title: Text('Logout'),
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(color: Colors.grey[100]),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari barang...',
                  hintStyle: GoogleFonts.lato(),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      'Filter: $_currentFilter',
                      style: GoogleFonts.lato(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.white,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadItems,
                    tooltip: 'Refresh Data',
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredItems.isEmpty
                      ? Center(
                        child: Text(
                          'Tidak ada data item',
                          style: GoogleFonts.lato(),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          return Card(
                            color: Colors.white,
                            shadowColor: Colors.grey[700],
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: ListTile(
                              title: Text(
                                item.nama,
                                style: GoogleFonts.lato(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Brand  : ${item.brand}',
                                    style: GoogleFonts.lato(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Seri       : ${item.seri}',
                                    style: GoogleFonts.lato(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Qty       : ${item.qty}',
                                    style: GoogleFonts.lato(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit),
                                    color: Colors.grey[700],
                                    onPressed: () => _editItem(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.qr_code),
                                    color: Colors.grey[700],
                                    onPressed: () {
                                      _showQRDialog(item);
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: Colors.grey[700],
                                    ),
                                    onPressed: () => _deleteItem(item.id!),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

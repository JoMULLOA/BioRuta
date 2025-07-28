import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/contacto_emergencia.dart';
import '../services/emergencia_service.dart';
import 'package:uuid/uuid.dart';

class ConfigurarContactosScreen extends StatefulWidget {
  const ConfigurarContactosScreen({super.key});

  @override
  State<ConfigurarContactosScreen> createState() => _ConfigurarContactosScreenState();
}

class _ConfigurarContactosScreenState extends State<ConfigurarContactosScreen> {
  final EmergenciaService _emergenciaService = EmergenciaService();
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  
  List<ContactoEmergencia> _contactos = [];
  bool _isLoading = true;
  bool _isFinalizando = false;
  bool _guardando = false;

  // Validar número de teléfono chileno (+569XXXXXXXX)
  bool _validarTelefonoChileno(String telefono) {
    final numeroLimpio = telefono.replaceAll(RegExp(r'[^\d+]'), '');
    // Debe tener formato +569XXXXXXXX (12 dígitos totales)
    return RegExp(r'^\+569\d{8}$').hasMatch(numeroLimpio);
  }

  // Validar email
  bool _validarEmail(String email) {
    if (email.trim().isEmpty) return false; // Email es obligatorio ahora
    // Validación más estricta de formato de email
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email.trim());
  }

  @override
  void initState() {
    super.initState();
    _cargarContactos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _cargarContactos() async {
    setState(() => _isLoading = true);
    
    try {
      final contactos = await _emergenciaService.obtenerContactos();
      setState(() {
        _contactos = contactos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar contactos: $e');
    }
  }

  Future<void> _agregarContacto() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _guardando = true);
    
    try {
      final contacto = ContactoEmergencia(
        id: const Uuid().v4(),
        nombre: _nombreController.text.trim(),
        telefono: _telefonoController.text.trim(),
        email: _emailController.text.trim(), // Ahora siempre se incluye
        fechaCreacion: DateTime.now(),
      );

      await _emergenciaService.agregarContacto(contacto);
      
      // Limpiar formulario
      _nombreController.clear();
      _telefonoController.clear();
      _emailController.clear();
      
      // Recargar contactos
      await _cargarContactos();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Contacto agregado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _mostrarError('Error al agregar contacto: $e');
    } finally {
      setState(() => _guardando = false);
    }
  }

  Future<void> _eliminarContacto(ContactoEmergencia contacto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Contacto'),
        content: Text('¿Estás seguro que quieres eliminar a ${contacto.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _emergenciaService.eliminarContacto(contacto.id);
        await _cargarContactos();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contacto eliminado'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        _mostrarError('Error al eliminar contacto: $e');
      }
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _finalizar() {
    if (_isFinalizando) return; // Prevenir múltiples llamadas
    
    setState(() => _isFinalizando = true);
    
    // Obtener argumentos ANTES del diálogo para evitar problemas de contexto
    final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final fromTutorial = arguments?['fromTutorial'] ?? false;
    
    if (_contactos.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Sin Contactos'),
          content: const Text(
            'No has configurado contactos de emergencia. '
            'Puedes agregar contactos ahora o continuar y configurarlos más tarde desde el menú de SOS.'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _isFinalizando = false);
              },
              child: const Text('Agregar Contacto'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar diálogo
                
                setState(() => _isFinalizando = false); // Resetear estado
                
                if (fromTutorial) {
                  // Si venimos del tutorial, ir al menú principal y limpiar el stack
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/mis-viajes',
                    (route) => false,
                  );
                } else {
                  // Si no venimos del tutorial, solo cerrar la pantalla
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Continuar Sin Contactos'),
            ),
          ],
        ),
      );
    } else {
      setState(() => _isFinalizando = false); // Resetear estado
      
      if (fromTutorial) {
        // Si venimos del tutorial, ir al menú principal y limpiar el stack
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/mis-viajes',
          (route) => false,
        );
      } else {
        // Si no venimos del tutorial, solo cerrar la pantalla
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Verificar si venimos del tutorial
    final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final fromTutorial = arguments?['fromTutorial'] ?? false;
    
    return PopScope(
      canPop: !fromTutorial, // No permitir pop normal si venimos del tutorial
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && fromTutorial) {
          // Si venimos del tutorial y se intenta hacer pop, ir al menú principal
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/mis-viajes',
            (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF2EEED),
        appBar: AppBar(
          title: const Text('Contactos SOS'),
          backgroundColor: const Color(0xFF854937), // Color café de la paleta
          foregroundColor: Colors.white,
          elevation: 0,
          leading: fromTutorial 
              ? IconButton(
                  icon: const Icon(Icons.home),
                  onPressed: () {
                    // Ir al menú principal cuando viene del tutorial
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/mis-viajes',
                      (route) => false,
                    );
                  },
                )
              : null, // Usar el botón de retroceso predeterminado si no viene del tutorial
          actions: [
            _isFinalizando
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _finalizar,
                    child: const Text(
                      'Finalizar',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
          ],
        ),
        body: (_isLoading && !_guardando)
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 20),
          _buildContactosList(),
          const SizedBox(height: 20),
          if (_contactos.length < 3) _buildAgregarContactoForm(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF854937).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF854937).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: const Color(0xFF854937)),
              const SizedBox(width: 8),
              Text(
                'Información Importante',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF854937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem('📱', '1-3 contactos máximo'),
          _buildInfoItem('📞', 'WhatsApp requerido'),
          _buildInfoItem('👥', 'Familiares o amigos'),
          _buildInfoItem('🌍', 'Números con código país'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Text(
              '💡 Ej: +56912345678 (Chile)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String emoji, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: Color(0xFF6B3B2D)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactosList() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contacts, color: Colors.red.shade600),
              const SizedBox(width: 8),
              Text(
                'Contactos Configurados (${_contactos.length}/3)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF854937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_contactos.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.person_add, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'No tienes contactos configurados',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._contactos.map((contacto) => _buildContactoItem(contacto)).toList(),
        ],
      ),
    );
  }

  Widget _buildContactoItem(ContactoEmergencia contacto) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.shade100,
          child: Text(
            contacto.nombre.isNotEmpty ? contacto.nombre[0].toUpperCase() : '?',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          contacto.nombre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _emergenciaService.formatearTelefono(contacto.telefono),
              style: const TextStyle(fontSize: 14),
            ),
            if (contacto.email != null)
              Text(
                contacto.email!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
          onPressed: () => _eliminarContacto(contacto),
        ),
        isThreeLine: contacto.email != null,
      ),
    );
  }

  Widget _buildAgregarContactoForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_add, color: Colors.green.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Agregar Nuevo Contacto',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF854937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Campo nombre
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(30),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es requerido';
                }
                if (value.trim().length < 3) {
                  return 'El nombre debe tener al menos 3 caracteres';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            
            const SizedBox(height: 16),
            
            // Campo teléfono
            TextFormField(
              controller: _telefonoController,
              decoration: const InputDecoration(
                labelText: 'Número de teléfono *',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
                hintText: '+56912345678',
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                LengthLimitingTextInputFormatter(12), // Máximo 12 caracteres
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El teléfono es requerido';
                }
                if (!_validarTelefonoChileno(value)) {
                  return 'Debe ser +569 seguido de 8 dígitos (ej: +56912345678)';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Campo email (obligatorio)
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email *',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
                helperText: 'Campo obligatorio',
              ),
              keyboardType: TextInputType.emailAddress,
              inputFormatters: [
                LengthLimitingTextInputFormatter(50), // Máximo 50 caracteres
              ],
              validator: (value) {
                if (!_validarEmail(value ?? '')) {
                  return 'Ingrese un email válido';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            // Botón agregar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _agregarContacto,
                icon: _guardando 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_guardando ? 'Guardando...' : 'Agregar Contacto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            
            if (_contactos.length >= 3)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Has alcanzado el máximo de 3 contactos de emergencia',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

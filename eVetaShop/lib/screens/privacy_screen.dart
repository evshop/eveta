import 'package:flutter/material.dart';
import 'package:eveta/common_widget/eveta_circular_back_button.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Política de Privacidad'),
        backgroundColor: const Color(0xFF09CB6B),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: const EvetaCircularBackButton(
          variant: EvetaCircularBackVariant.onDarkBackground,
        ),
        leadingWidth: 56,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Última actualización: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Información que recopilamos',
              'Recopilamos la información que nos proporcionas al registrarte: correo electrónico, nombre de usuario, número de teléfono y contraseña. Si inicias sesión con Google, obtenemos tu correo y nombre de perfil. También registramos datos de uso de la aplicación (sesiones, compras, interacciones) para mejorar el servicio.',
            ),
            _buildSection(
              '2. Uso de la información',
              'Usamos tu información para: gestionar tu cuenta, procesar pedidos, enviar códigos de verificación por WhatsApp cuando lo requieras, personalizar tu experiencia y comunicarnos contigo sobre actualizaciones o soporte.',
            ),
            _buildSection(
              '3. Inicio de sesión con Google',
              'Si eliges iniciar sesión con Google, compartimos con Supabase (nuestro proveedor de autenticación) tu correo y nombre para crear o vincular tu cuenta. Esta integración está sujeta a la Política de Privacidad de Google.',
            ),
            _buildSection(
              '4. Verificación por WhatsApp',
              'Cuando solicitas un código de verificación por WhatsApp, enviamos un mensaje a tu número de teléfono. Utilizamos proveedores oficiales (Meta/Twilio) para el envío. No compartimos tu número con terceros con fines de marketing.',
            ),
            _buildSection(
              '5. Almacenamiento y seguridad',
              'Los datos se almacenan en servidores seguros (Supabase) con medidas de cifrado y controles de acceso. Las contraseñas se guardan de forma hasheada. No almacenamos datos de tarjetas de crédito en nuestros servidores.',
            ),
            _buildSection(
              '6. Compartir información',
              'No vendemos tu información personal. Podemos compartir datos con proveedores que nos ayudan a operar el servicio (hosting, envío de mensajes, análisis), bajo acuerdos de confidencialidad.',
            ),
            _buildSection(
              '7. Tus derechos',
              'Puedes solicitar acceso, corrección o eliminación de tus datos personales contactando a soporte. También puedes cerrar tu cuenta desde la aplicación.',
            ),
            _buildSection(
              '8. Cambios',
              'Podemos actualizar esta Política de Privacidad. Los cambios importantes se comunicarán por la aplicación o por correo. El uso continuado implica la aceptación de la política actualizada.',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF09CB6B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

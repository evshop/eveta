import 'package:flutter/material.dart';
import 'package:eveta/common_widget/eveta_circular_back_button.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Términos y Condiciones'),
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
              '1. Aceptación',
              'Al utilizar la aplicación eVeta, te registrarte o iniciar sesión, aceptas estos Términos y Condiciones en su totalidad.',
            ),
            _buildSection(
              '2. Descripción del servicio',
              'eVeta es una aplicación de comercio electrónico que permite a los usuarios explorar productos, realizar compras y gestionar su cuenta. Los vendedores pueden ofrecer sus productos a través de la plataforma.',
            ),
            _buildSection(
              '3. Registro y cuenta',
              'Para usar ciertas funciones debes crear una cuenta proporcionando información veraz (correo electrónico, nombre de usuario, número de teléfono y contraseña). Eres responsable de mantener la confidencialidad de tu contraseña y de todas las actividades realizadas en tu cuenta.',
            ),
            _buildSection(
              '4. Uso aceptable',
              'Te comprometes a usar eVeta de forma legal y respetuosa. No está permitido: usar la plataforma para fines ilícitos, suplantar identidades, publicar contenido falso o engañoso, o interferir con el funcionamiento de la aplicación.',
            ),
            _buildSection(
              '5. Compras y pagos',
              'Las transacciones entre compradores y vendedores se rigen por los términos acordados en cada venta. eVeta actúa como intermediario y no es responsable de la calidad de los productos ofrecidos por terceros.',
            ),
            _buildSection(
              '6. Modificaciones',
              'Nos reservamos el derecho de modificar estos Términos en cualquier momento. Los cambios entrarán en vigor al publicarse en la aplicación. El uso continuado de eVeta tras las modificaciones implica tu aceptación.',
            ),
            _buildSection(
              '7. Contacto',
              'Para consultas sobre estos Términos y Condiciones puedes contactarnos a través de los canales de soporte indicados en la aplicación.',
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

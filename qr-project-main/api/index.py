import os
import io
from flask import Flask, render_template, request, jsonify, send_file
import qrcode
from PIL import Image, ImageDraw, ImageOps

app = Flask(__name__, template_folder='../templates', static_folder='../static')

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/generate-qr', methods=['POST'])
def generate_qr():
    try:
        data = request.json
        text_content = data.get('textContent')
        is_dark = data.get('darkMode', False)
        
        # Colores y selección de archivo
        fill = "white" if is_dark else "black"
        back = "black" if is_dark else "white"
        icon_name = "iconoblack.png" if is_dark else "iconowhite.png"

        # 1. REDUCIR DENSIDAD: Usamos version=1 para que tenga menos puntos (módulos)
        # fit=True ajustará automáticamente si el texto es muy largo
        qr = qrcode.QRCode(
            version=1, 
            error_correction=qrcode.constants.ERROR_CORRECT_H,
            box_size=10,
            border=4,
        )
        qr.add_data(text_content)
        qr.make(fit=True)

        qr_img = qr.make_image(fill_color=fill, back_color=back).convert('RGB')
        
        logo_path = os.path.join(app.static_folder, icon_name)
        
        if os.path.exists(logo_path):
            logo = Image.open(logo_path).convert("RGBA")
            
            qr_width, qr_height = qr_img.size
            logo_size = int(qr_width / 5)
            padding = 12 # Espacio para el borde
            bg_size = logo_size + padding
            
            # 2. CREAR FONDO REDONDEADO
            # Si es modo oscuro, el fondo del logo será negro con borde blanco
            # Si es modo claro, el fondo será negro para que el icono blanco resalte
            bg_color = "black" if (is_dark or not is_dark) else back 
            
            # Creamos una máscara para el border-radius
            mask = Image.new('L', (bg_size, bg_size), 0)
            draw = ImageDraw.Draw(mask)
            draw.rounded_rectangle((0, 0, bg_size, bg_size), radius=15, fill=255)
            
            # Crear el contenedor del logo
            logo_container = Image.new("RGBA", (bg_size, bg_size), (0, 0, 0, 0))
            
            # Dibujar el fondo sólido (negro en ambos casos para contraste)
            inner_draw = ImageDraw.Draw(logo_container)
            inner_draw.rounded_rectangle((0, 0, bg_size, bg_size), radius=15, fill="black")
            
            # 3. AÑADIR BORDE BLANCO (Solo si es modo oscuro para que resalte)
            if is_dark:
                inner_draw.rounded_rectangle((0, 0, bg_size, bg_size), radius=15, outline="white", width=3)
            
            # Redimensionar y pegar el logo transparente dentro
            logo = logo.resize((logo_size, logo_size), Image.Resampling.LANCZOS)
            logo_container.paste(logo, (padding // 2, padding // 2), mask=logo)
            
            # Pegar el contenedor final en el centro del QR
            pos = ((qr_width - bg_size) // 2, (qr_height - bg_size) // 2)
            qr_img.paste(logo_container, pos, mask=mask)

        img_io = io.BytesIO()
        qr_img.save(img_io, 'PNG')
        img_io.seek(0)
        return send_file(img_io, mimetype='image/png')
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

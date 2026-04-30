document.addEventListener('DOMContentLoaded', () => {
    const themeBtn = document.getElementById('theme-toggle');
    const qrInput = document.getElementById('qr-input-image');
    const textContent = document.getElementById('text-content');
    const form = document.getElementById('qr-generator-form');
    const qrImage = document.getElementById('qr-image');
    let isDarkMode = false;

    themeBtn.onclick = () => {
        isDarkMode = !isDarkMode;
        document.body.classList.toggle('dark-mode');
        themeBtn.innerText = isDarkMode ? '☀️ Modo Día' : '🌙 Modo Oscuro';
    };

    qrInput.onchange = (e) => {
        const file = e.target.files[0];
        const reader = new FileReader();
        reader.onload = (event) => {
            const img = new Image();
            img.onload = () => {
                const canvas = document.createElement('canvas');
                const ctx = canvas.getContext('2d');
                canvas.width = img.width; canvas.height = img.height;
                ctx.drawImage(img, 0, 0);
                const data = ctx.getImageData(0, 0, canvas.width, canvas.height);
                const code = jsQR(data.data, data.width, data.height);
                if (code) textContent.value = code.data;
            };
            img.src = event.target.result;
        };
        reader.readAsDataURL(file);
    };

    form.onsubmit = async (e) => {
        e.preventDefault();
        const res = await fetch('/api/generate-qr', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                textContent: textContent.value,
                darkMode: isDarkMode
            })
        });
        if (res.ok) {
            const blob = await res.blob();
            qrImage.src = URL.createObjectURL(blob);
            qrImage.style.display = 'inline-block';
        }
    };
});

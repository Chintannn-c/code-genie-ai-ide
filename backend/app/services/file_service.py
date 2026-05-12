import os
import aiofiles
from uuid import uuid4
from fastapi import UploadFile
from app.config import get_settings

settings = get_settings()
UPLOAD_DIR = settings.UPLOAD_PATH

async def save_upload(user_id: str, file: UploadFile) -> str:
    """Save an uploaded file to local storage. Returns relative path."""
    user_dir = os.path.join(UPLOAD_DIR, user_id)
    if not os.path.exists(user_dir):
        os.makedirs(user_dir)
        
    # Generate unique filename to avoid collisions
    ext = os.path.splitext(file.filename)[1]
    safe_name = f"{uuid4()}{ext}"
    file_path = os.path.join(user_dir, safe_name)
    
    async with aiofiles.open(file_path, 'wb') as out_file:
        content = await file.read()
        await out_file.write(content)
        
    return file_path

from app.services.ocr_service import OCRService

async def read_file_content(file_path: str) -> str:
    """Read content of a stored file, with OCR support for images."""
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"File not found at {file_path}")
        
    # Check if it's an image
    if OCRService.is_image(file_path):
        async with aiofiles.open(file_path, 'rb') as f:
            content = await f.read()
            return OCRService.extract_text(content)

    async with aiofiles.open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        return await f.read()

def get_language_from_ext(filename: str) -> str:
    """Infer language from file extension."""
    ext = os.path.splitext(filename)[1].lower()
    
    mapping = {
        # 🧠 Core Languages
        '.py': 'python',
        '.dart': 'dart',
        '.js': 'javascript',
        '.mjs': 'javascript',
        '.cjs': 'javascript',
        '.ts': 'typescript',
        '.java': 'java',
        '.kt': 'kotlin',
        '.kts': 'kotlin',
        '.swift': 'swift',
        '.go': 'go',
        '.rs': 'rust',
        '.rb': 'ruby',
        '.php': 'php',
        '.cs': 'csharp',

        # 💻 C / C++ Family
        '.c': 'c',
        '.h': 'c',
        '.cpp': 'cpp',
        '.cc': 'cpp',
        '.cxx': 'cpp',
        '.hpp': 'cpp',
        '.hh': 'cpp',

        # 🌐 Web
        '.html': 'html',
        '.htm': 'html',
        '.css': 'css',
        '.scss': 'scss',
        '.sass': 'sass',
        '.less': 'less',

        # 📦 Data / Config
        '.json': 'json',
        '.yaml': 'yaml',
        '.yml': 'yaml',
        '.xml': 'xml',
        '.toml': 'toml',
        '.ini': 'ini',
        '.env': 'env',

        # 🧮 Database
        '.sql': 'sql',
        '.psql': 'sql',
        '.sqlite': 'sql',

        # 🐚 Shell / Scripts
        '.sh': 'shell',
        '.bash': 'bash',
        '.zsh': 'zsh',
        '.fish': 'fish',

        # 📱 Mobile / Cross-platform
        '.gradle': 'gradle',
        '.groovy': 'groovy',

        # 🧠 Functional / Other
        '.scala': 'scala',
        '.clj': 'clojure',
        '.hs': 'haskell',
        '.elm': 'elm',
        '.erl': 'erlang',
        '.ex': 'elixir',
        '.exs': 'elixir',

        # 🧾 Markup / Docs
        '.md': 'markdown',
        '.markdown': 'markdown',
        '.tex': 'latex',
        '.rst': 'restructuredtext',

        # 🎮 / Low-level
        '.asm': 'assembly',
        '.s': 'assembly',

        # 🧩 Others
        '.lua': 'lua',
        '.pl': 'perl',
        '.pm': 'perl',
        '.r': 'r',
        '.mat': 'matlab',
        '.m': 'objective-c',

        # ⚙️ DevOps / Infra
        '.dockerfile': 'docker',
        '.tf': 'terraform',

        # 🔐 Misc
        '.bat': 'batch',
        '.ps1': 'powershell',

        # 📊 Data Science
        '.ipynb': 'jupyter',

        # 🧱 Frontend Frameworks
        '.vue': 'vue',
        '.svelte': 'svelte',

        # 🧬 Others (rare but useful)
        '.nim': 'nim',
        '.zig': 'zig',
        '.cr': 'crystal',
        '.v': 'vlang',
    }
    return mapping.get(ext, 'text')

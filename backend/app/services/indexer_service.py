import os
import logging
from typing import List, Dict, Any
try:
    import chromadb
    from chromadb.utils import embedding_functions
except ImportError:
    chromadb = None

try:
    import PyPDF2
    import pytesseract
    from PIL import Image
except ImportError:
    PyPDF2 = None
    pytesseract = None
    Image = None

from app.config import get_settings

logger = logging.getLogger(__name__)

class IndexerService:
    def __init__(self):
        self.settings = get_settings()
        self.workspace_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
        self.db_path = os.path.join(self.settings.ARTIFACTS_PATH, "chroma_db")
        self.client = None
        self.collection = None
        
        if chromadb:
            try:
                self.client = chromadb.PersistentClient(path=self.db_path)
                # Using a default lightweight embedding function
                self.ef = embedding_functions.DefaultEmbeddingFunction()
                self.collection = self.client.get_or_create_collection(
                    name="workspace_index",
                    embedding_function=self.ef
                )
                logger.info(f"🧠 Workspace Indexer Initialized at: {self.db_path}")
            except Exception as e:
                logger.error(f"❌ Failed to initialize ChromaDB: {e}")

    async def index_workspace(self):
        """Recursively scans and indexes the workspace."""
        if not self.collection:
            return {"status": "error", "message": "ChromaDB not initialized"}

        logger.info("🔍 Starting workspace indexing...")
        
        count = 0
        for root, dirs, files in os.walk(self.workspace_root):
            # Skip noise
            dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ['node_modules', 'build', '__pycache__', 'ios', 'android']]
            
            for file in files:
                if file.endswith(('.dart', '.py', '.js', '.ts', '.html', '.css', '.md', '.pdf', '.png', '.jpg', '.jpeg')):
                    file_path = os.path.join(root, file)
                    rel_path = os.path.relpath(file_path, self.workspace_root)
                    
                    try:
                        content = ""
                        # Text Files
                        if file.endswith(('.dart', '.py', '.js', '.ts', '.html', '.css', '.md')):
                            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                                content = f.read()
                        # PDF Files
                        elif file.endswith('.pdf') and PyPDF2:
                            content = self._extract_pdf_text(file_path)
                        # Image Files (OCR)
                        elif file.endswith(('.png', '.jpg', '.jpeg')) and pytesseract and Image:
                            content = self._extract_image_text(file_path)
                            
                        if not content.strip():
                            continue
                            
                        # Split large files into chunks
                        chunks = self._chunk_text(content)
                        
                        for i, chunk in enumerate(chunks):
                            chunk_id = f"{rel_path}_chunk_{i}"
                            self.collection.upsert(
                                documents=[chunk],
                                metadatas=[{"path": rel_path, "chunk": i}],
                                ids=[chunk_id]
                            )
                        count += 1
                    except Exception as e:
                        logger.warning(f"⚠️ Failed to index {rel_path}: {e}")

        logger.info(f"✅ Indexed {count} files in workspace.")
        return {"status": "success", "files_indexed": count}

    async def index_single_file(self, file_path: str, user_id: str, file_id: str, task_id: str = None):
        """Indexes a single uploaded file asynchronously and reports progress to TaskEngine."""
        from app.services.task_engine import task_engine, TaskState
        import asyncio
        
        if not self.collection:
            logger.error("ChromaDB not initialized, skipping semantic indexing.")
            if task_id:
                await task_engine.update_task_state(task_id, TaskState.FAILED, "Vector database unavailable.")
            return

        if task_id:
            await task_engine.update_task_state(task_id, TaskState.INDEXING, "Extracting text content...", 0.2)

        rel_path = os.path.basename(file_path)
        content = ""
        
        try:
            # Simulate slight delay to avoid blocking event loop completely
            await asyncio.sleep(0.1)
            
            # Text Files
            if file_path.endswith(('.dart', '.py', '.js', '.ts', '.html', '.css', '.md', '.txt', '.json', '.yaml', '.yml', '.cpp', '.c', '.java', '.go', '.rs')):
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
            # PDF Files
            elif file_path.endswith('.pdf') and PyPDF2:
                content = self._extract_pdf_text(file_path)
            # Image Files
            elif file_path.endswith(('.png', '.jpg', '.jpeg')) and pytesseract and Image:
                content = self._extract_image_text(file_path)

            if not content.strip():
                if task_id:
                    await task_engine.update_task_state(task_id, TaskState.COMPLETED, "File processed (No text found).", 1.0)
                return

            if task_id:
                await task_engine.update_task_state(task_id, TaskState.INDEXING, f"Chunking document ({len(content)} chars)...", 0.5)

            chunks = self._chunk_text(content, size=2000)
            
            if task_id:
                await task_engine.update_task_state(task_id, TaskState.INDEXING, f"Generating {len(chunks)} embeddings...", 0.7)

            for i, chunk in enumerate(chunks):
                chunk_id = f"user_{user_id}_file_{file_id}_chunk_{i}"
                self.collection.upsert(
                    documents=[chunk],
                    metadatas=[{"user_id": user_id, "file_id": file_id, "path": rel_path, "chunk": i}],
                    ids=[chunk_id]
                )
                await asyncio.sleep(0.01) # Yield to event loop
            
            logger.info(f"✅ Indexed {len(chunks)} chunks for {rel_path}.")
            if task_id:
                await task_engine.update_task_state(task_id, TaskState.COMPLETED, "Vector indexing completed successfully.", 1.0)
                
        except Exception as e:
            logger.error(f"Failed to index single file {file_path}: {e}")
            if task_id:
                await task_engine.update_task_state(task_id, TaskState.FAILED, f"Extraction failed: {str(e)}")

    def _chunk_text(self, text: str, size: int = 1000) -> List[str]:
        """Simple sliding window chunking."""
        return [text[i:i+size] for i in range(0, len(text), size)]

    def _extract_pdf_text(self, file_path: str) -> str:
        """Extracts text from a PDF file using PyPDF2."""
        text = ""
        try:
            with open(file_path, 'rb') as f:
                reader = PyPDF2.PdfReader(f)
                for page in reader.pages:
                    text += page.extract_text() + "\n"
        except Exception as e:
            logger.error(f"PDF Extraction Error: {e}")
        return text

    def _extract_image_text(self, file_path: str) -> str:
        """Extracts text from an image using Tesseract OCR."""
        text = ""
        try:
            # On Windows, you might need to specify the tesseract_cmd path if it's not in PATH
            # pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
            img = Image.open(file_path)
            text = pytesseract.image_to_string(img)
        except Exception as e:
            logger.error(f"OCR Extraction Error: {e}")
        return text

    async def search_context(self, query: str, limit: int = 5) -> List[Dict[str, Any]]:
        """Searches for relevant code snippets."""
        if not self.collection:
            return []

        try:
            results = self.collection.query(
                query_texts=[query],
                n_results=limit
            )
            
            context = []
            for i in range(len(results['documents'][0])):
                # Check for path and generic ID metadata structure
                metadata = results['metadatas'][0][i]
                source_path = metadata.get('path', 'Unknown File')
                if 'file_id' in metadata:
                    source_path = f"Uploaded File: {source_path}"
                    
                context.append({
                    "content": results['documents'][0][i],
                    "path": source_path
                })
            return context
        except Exception as e:
            logger.error(f"❌ Search Error: {e}")
            return []

# Singleton instance
indexer = IndexerService()

import logging
from typing import List, Dict, Any
from app.config import get_settings

try:
    import chromadb
    from chromadb.config import Settings
except ImportError:
    chromadb = None
    Settings = None

logger = logging.getLogger(__name__)

class VectorService:
    """Semantic Memory & RAG Engine (ChromaDB)."""
    
    def __init__(self):
        settings = get_settings()
        self.client = None
        self.collection = None
        if chromadb is None or Settings is None:
            logger.warning("ChromaDB is not installed. Semantic memory is disabled.")
            return

        self.client = chromadb.HttpClient(
            host=getattr(settings, "CHROMA_HOST", "localhost"),
            port=getattr(settings, "CHROMA_PORT", 8000),
            settings=Settings(allow_reset=True, anonymized_telemetry=False)
        )
        self.collection = self.client.get_or_create_collection("code_genie_memory")

    async def index_message(self, chat_id: str, message: Dict[str, Any]):
        """Index a chat message for semantic retrieval."""
        if self.collection is None:
            return
        content = message.get("content", "")
        if not content: return
        
        self.collection.add(
            documents=[content],
            metadatas=[{"chat_id": chat_id, "role": message.get("role")}],
            ids=[f"msg_{chat_id}_{message.get('id', 'temp')}"]
        )

    async def query_context(self, query: str, n_results: int = 5) -> List[str]:
        """Retrieve relevant context for a given prompt."""
        if self.collection is None:
            return []
        results = self.collection.query(
            query_texts=[query],
            n_results=n_results
        )
        return results['documents'][0] if results['documents'] else []

    async def index_codebase(self, project_id: str, files: List[Dict[str, str]]):
        """Perform semantic indexing of an entire project codebase."""
        if self.collection is None:
            return
        documents = [f["content"] for f in files]
        metadatas = [{"project_id": project_id, "path": f["path"]} for f in files]
        ids = [f"{project_id}_{f['path']}" for f in files]
        
        self.collection.add(
            documents=documents,
            metadatas=metadatas,
            ids=ids
        )

vector_service = VectorService()

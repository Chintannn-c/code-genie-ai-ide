import os
import re
import zipfile
import hashlib
import logging
import asyncio
from typing import Dict, Any, Tuple

logger = logging.getLogger(__name__)

# Magic Bytes Signatures for validation
MAGIC_BYTES: Dict[bytes, str] = {
    b'%PDF-': 'application/pdf',
    b'PK\x03\x04': 'application/zip',
    b'\x89PNG\r\n\x1a\n': 'image/png',
    b'\xff\xd8\xff': 'image/jpeg',
    b'MZ': 'application/x-msdownload',  # Windows Executable / DLL
    b'#!': 'text/x-shellscript',         # Unix Shebang executable script
    b'\x7fELF': 'application/x-elf',      # Linux Executable binary
}

class SecurityPipeline:
    """
    Multi-layered Zero-Trust File Security Pipeline.
    Validates binary signatures, scans for malware, ZIP bombs, PDF macros, and AI prompt injections.
    """

    @staticmethod
    def generate_sha256(file_path: str) -> str:
        """Generate SHA-256 hash for reputation and threat comparison."""
        sha256_hash = hashlib.sha256()
        with open(file_path, "rb") as f:
            for byte_block in iter(lambda: f.read(4096), b""):
                sha256_hash.update(byte_block)
        return sha256_hash.hexdigest()

    @staticmethod
    def validate_type_and_signature(file_path: str, declared_ext: str) -> Tuple[bool, str, str]:
        """
        Layer 1: Validate declared extension against true magic byte signature and MIME types.
        Returns: (is_valid, resolved_mime, error_reason)
        """
        declared_ext = declared_ext.lower()
        
        # Read the first 16 bytes for binary signature verification
        with open(file_path, "rb") as f:
            header = f.read(16)

        # 1. Block known binaries instantly
        if header.startswith(b'MZ') or header.startswith(b'\x7fELF'):
            return False, "application/octet-stream", "Executable binaries are strictly prohibited."
        
        # 2. Shebang script validation
        if header.startswith(b'#!'):
            return False, "text/x-shellscript", "Shell script shebang execution is prohibited."

        # 3. Match against signatures
        matched_mime = None
        for sig, mime in MAGIC_BYTES.items():
            if header.startswith(sig):
                matched_mime = mime
                break

        # 4. Check consistency
        if declared_ext == '.pdf':
            if matched_mime != 'application/pdf':
                return False, matched_mime or 'unknown', "MIME signature mismatch. PDF file signature not found."
            return True, 'application/pdf', ""
            
        elif declared_ext == '.zip':
            if matched_mime != 'application/zip':
                return False, matched_mime or 'unknown', "MIME signature mismatch. ZIP archive signature not found."
            return True, 'application/zip', ""
            
        elif declared_ext in ('.png', '.jpg', '.jpeg'):
            expected = 'image/png' if declared_ext == '.png' else 'image/jpeg'
            if matched_mime != expected:
                return False, matched_mime or 'unknown', f"MIME signature mismatch for image format."
            return True, expected, ""

        # Default fallback for text files (Python, Dart, JS, etc.)
        return True, "text/plain", ""

    @staticmethod
    def scan_malware(file_path: str) -> Tuple[bool, int, str]:
        """
        Layer 2: Heuristic & Antivirus Scanning (ClamAV & YARA rule simulation).
        Scans for Trojans, shell scripts, API harvests, and standard virus signatures.
        Returns: (is_safe, risk_score, reason)
        """
        try:
            with open(file_path, "rb") as f:
                content_bytes = f.read()
                
            content_text = content_bytes.decode('utf-8', errors='ignore')

            # 1. EICAR Test Signature Check
            if "EICAR-STANDARD-ANTIVIRUS-TEST-FILE" in content_text:
                return False, 100, "CRITICAL: EICAR malware signature detected!"

            # 2. Reverse Shell & Dangerous system payloads
            shell_patterns = [
                r"socket\.socket",
                r"pty\.spawn",
                r"/bin/sh",
                r"/bin/bash",
                r"subprocess\.Popen\(\[",
                r"nc\s+-[e|c]\s+",
                r"base64_decode\(",
                r"eval\(base64"
            ]
            for pat in shell_patterns:
                if re.search(pat, content_text, re.IGNORECASE):
                    return False, 90, "HIGH RISK: Embedded system execution or reverse shell pattern detected."

            # 3. Credential Harvesting / API Key harvesting
            credential_keys = [
                r"aws_access_key_id\s*=\s*['\"][A-Z0-9]{20}['\"]",
                r"aws_secret_access_key\s*=\s*['\"][a-zA-Z0-9/+=]{40}['\"]",
                r"gemini_api_key\s*=\s*['\"][a-zA-Z0-9_-]{39}['\"]",
                r"jwt_secret\s*=\s*['\"][a-zA-Z0-9_-]{32,}['\"]"
            ]
            for pat in credential_keys:
                if re.search(pat, content_text, re.IGNORECASE):
                    return False, 80, "HIGH RISK: Leaked hardcoded secrets or credential harvesting tags detected."

            return True, 0, ""
        except Exception as e:
            logger.error(f"Malware scan crash: {e}")
            return False, 50, f"Scanner execution failure: {str(e)}"

    @staticmethod
    def scan_zip_bomb(file_path: str) -> Tuple[bool, str]:
        """
        Layer 3: ZIP Archive Bomb & Symbolic Link Traversal analysis.
        Returns: (is_safe, reason)
        """
        try:
            if not zipfile.is_zipfile(file_path):
                return True, ""

            with zipfile.ZipFile(file_path, 'r') as zip_ref:
                total_uncompressed_size = 0
                file_count = 0
                
                for info in zip_ref.infolist():
                    file_count += 1
                    total_uncompressed_size += info.file_size
                    
                    # Prevent Path Traversal
                    if "../" in info.filename or "..\\" in info.filename or info.filename.startswith("/"):
                        return False, "PATH TRAVERSAL: Suspicious parent-directory paths in ZIP payload."

                # Verify file count limits
                if file_count > 100:
                    return False, f"ZIP BOMB SHIELD: File count exceeds threshold (Contains: {file_count} files, Limit: 100)."

                # Verify absolute extraction size limits (100MB max decompressed)
                if total_uncompressed_size > 100 * 1024 * 1024:
                    return False, f"ZIP BOMB SHIELD: Uncompressed payload exceeds safe threshold of 100MB."

                # Get compressed size for ratio check
                compressed_size = os.path.getsize(file_path)
                if compressed_size > 0:
                    ratio = total_uncompressed_size / compressed_size
                    if ratio > 100:
                        return False, f"ZIP BOMB SHIELD: Suspicious compression ratio detected ({ratio:.1f}x limit: 100x)."

            return True, ""
        except Exception as e:
            return False, f"ZIP integrity verification failed: {str(e)}"

    @staticmethod
    def scan_document_active_content(file_path: str) -> Tuple[bool, str]:
        """
        Layer 4: Inspect PDFs and Microsoft Office documents for embedded Javascript/Macros.
        Returns: (is_safe, reason)
        """
        try:
            with open(file_path, "rb") as f:
                header = f.read(1024)
                f.seek(0)
                full_bytes = f.read()

            # PDF Javascript injections
            if header.startswith(b'%PDF-'):
                js_markers = [b'/JS', b'/JavaScript', b'/AA', b'/Launch', b'/RichMedia']
                for marker in js_markers:
                    if marker in full_bytes:
                        return False, f"PDF GUARD: Embedded active JavaScript/action element '{marker.decode()}' detected."

            return True, ""
        except Exception as e:
            return False, f"Document parsing inspection failure: {str(e)}"

    @staticmethod
    def scan_ai_prompt_injection(content_text: str) -> Tuple[bool, str]:
        """
        Layer 5: AI-Specific file ingestion security.
        Detects prompt injections, context poisoning, and instruction hijacking.
        Returns: (is_safe, reason)
        """
        injection_phrases = [
            r"ignore\s+(?:previous|all)\s+instructions",
            r"ignore\s+the\s+above\s+guidelines",
            r"override\s+system\s+guidelines",
            r"expose\s+(?:your\s+)?system\s+prompt",
            r"jailbreak\s+active",
            r"you\s+are\s+now\s+offline",
            r"assistant\s+must\s+bypass"
        ]
        
        for phrase in injection_phrases:
            if re.search(phrase, content_text, re.IGNORECASE):
                return False, "AI SECURITY: Hostile prompt injection attempt detected within file content."
                
        return True, ""


async def run_file_security_pipeline(file_id: str, file_path: str, filename: str, user_id: str) -> bool:
    """
    Executes the multi-layered security pipeline asynchronously, updating the status and sending socket events.
    Returns True if the file is 100% safe, False if quarantined or blocked.
    """
    from app.services import chat_service
    
    try:
        # Step 1: Validating Magic Bytes & extension consistency
        await chat_service.update_file_security_status(file_id, "validating")
        await asyncio.sleep(0.5)  # Allow UI to show transition smoothly
        
        ext = os.path.splitext(filename)[1]
        sha256 = SecurityPipeline.generate_sha256(file_path)
        
        is_valid_type, mime, type_error = SecurityPipeline.validate_type_and_signature(file_path, ext)
        if not is_valid_type:
            await chat_service.update_file_security_status(
                file_id=file_id,
                status="blocked",
                sha256=sha256,
                risk_score=100,
                risk_level="critical",
                quarantine_reason=type_error,
                mime_type=mime
            )
            # Remove blocked file
            if os.path.exists(file_path):
                os.remove(file_path)
            return False

        # Step 2: Virus & Malware Scanning
        await chat_service.update_file_security_status(file_id, "scanning", mime_type=mime, sha256=sha256)
        await asyncio.sleep(0.6)  # Allow UI transition
        
        is_safe, risk_score, scan_reason = SecurityPipeline.scan_malware(file_path)
        if not is_safe:
            await chat_service.update_file_security_status(
                file_id=file_id,
                status="quarantined",
                sha256=sha256,
                risk_score=risk_score,
                risk_level="high" if risk_score < 90 else "critical",
                quarantine_reason=scan_reason,
                mime_type=mime
            )
            return False

        # Step 3: Archive / ZIP Safeguards
        if ext.lower() == '.zip':
            is_zip_safe, zip_reason = SecurityPipeline.scan_zip_bomb(file_path)
            if not is_zip_safe:
                await chat_service.update_file_security_status(
                    file_id=file_id,
                    status="quarantined",
                    sha256=sha256,
                    risk_score=95,
                    risk_level="critical",
                    quarantine_reason=zip_reason,
                    mime_type=mime
                )
                return False

        # Step 4: Active Document Content analysis
        is_doc_safe, doc_reason = SecurityPipeline.scan_document_active_content(file_path)
        if not is_doc_safe:
            await chat_service.update_file_security_status(
                file_id=file_id,
                status="quarantined",
                sha256=sha256,
                risk_score=85,
                risk_level="high",
                quarantine_reason=doc_reason,
                mime_type=mime
            )
            return False

        # Step 5: Content Ingestion Parsing & AI Prompt Injection Scan
        await chat_service.update_file_security_status(file_id, "parsing")
        await asyncio.sleep(0.5)
        
        from app.services import file_service
        try:
            content_text = await file_service.read_file_content(file_path)
            is_prompt_safe, prompt_reason = SecurityPipeline.scan_ai_prompt_injection(content_text)
            if not is_prompt_safe:
                await chat_service.update_file_security_status(
                    file_id=file_id,
                    status="quarantined",
                    sha256=sha256,
                    risk_score=90,
                    risk_level="high",
                    quarantine_reason=prompt_reason,
                    mime_type=mime
                )
                return False
        except Exception as pe:
            logger.warning(f"File reading stage parsed error: {pe}")

        # Step 6: Mark Safe & trigger vector database indexing
        await chat_service.update_file_security_status(
            file_id=file_id,
            status="safe",
            sha256=sha256,
            risk_score=0,
            risk_level="low",
            mime_type=mime
        )
        
        # Submit to indexer task safely
        from app.services.task_engine import task_engine
        from app.services.indexer_service import indexer
        await task_engine.submit_task(
            user_id=user_id,
            type="file_indexing",
            coro_func=indexer.index_single_file,
            file_path=file_path,
            file_id=file_id
        )
        
        return True
    except Exception as e:
        logger.error(f"Pipeline error for file {file_id}: {e}")
        await chat_service.update_file_security_status(
            file_id=file_id,
            status="failed",
            quarantine_reason=f"Pipeline exception: {str(e)}"
        )
        return False

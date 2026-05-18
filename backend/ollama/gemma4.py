# python ollama/gemma4.py


import os
import subprocess
from ollama import chat

MODEL_NAME = "baby-gemma"
GGUF_PATH = "backend/output/baby-gemma.gguf"


def model_exists(model_name: str) -> bool:
    """
    Check whether model already exists in Ollama
    """

    try:
        result = subprocess.run(
            ["ollama", "list"],
            capture_output=True,
            text=True
        )

        return model_name in result.stdout

    except Exception as e:
        print(f"Error checking model: {e}")
        return False


def create_ollama_model():
    """
    Automatically create Ollama model from GGUF
    """

    modelfile_content = f"""
FROM {os.path.abspath(GGUF_PATH)}
"""

    modelfile_path = "Modelfile"

    # create modelfile
    with open(modelfile_path, "w") as f:
        f.write(modelfile_content)

    print("Creating Ollama model from GGUF...")

    result = subprocess.run(
        [
            "ollama",
            "create",
            MODEL_NAME,
            "-f",
            modelfile_path
        ],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        raise Exception(result.stderr)

    print("Model created successfully")


def ensure_model_loaded():
    """
    Ensure GGUF imported into Ollama
    """

    if not os.path.exists(GGUF_PATH):
        return False

    if not model_exists(MODEL_NAME):
        create_ollama_model()

    return True


def ChatWithGemma4(message: str):

    try:

        # local GGUF exists
        if ensure_model_loaded():

            response = chat(
                model=MODEL_NAME,
                messages=[
                    {
                        'role': 'user',
                        'content': message
                    }
                ],
            )

            return response.message.content

        # fallback cloud/local pulled model
        else:

            response = chat(
                model='gemma3:4b',
                messages=[
                    {
                        'role': 'user',
                        'content': message
                    }
                ],
            )

            return response.message.content

    except Exception as e:
        return f"Error: {str(e)}"

def ChatWithGemma4WithImage(message: str, image_path: str):
    with open(image_path, 'rb') as f:
        image_data = f.read()

    response = chat(
        model='gemma4:e2b',
        messages=[
            {
                'role': 'user',
                'content': message,
                'images': [image_data]   # ✅ images is a top-level field, a list of bytes
            }
        ],
    )
    return response.message.content


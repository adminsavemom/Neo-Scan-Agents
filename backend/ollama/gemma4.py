# python ollama/gemma4.py


from ollama import chat

def ChatWithGemma4(message: str):
    response = chat(
        model='gemma4:e2b',
        messages=[{'role': 'user', 'content': message}],
    )
    return response.message.content

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


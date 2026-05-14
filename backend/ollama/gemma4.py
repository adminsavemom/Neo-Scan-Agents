from ollama import chat

def ChatWithGemma3(message: str):
    response = chat(
        model='gemma4:e2b',
        messages=[{'role': 'user', 'content': message}],
    )
    return response.message.content

def ChatWithGemma3WithImage(message: str, image_path: str):
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

# if __name__ == "__main__":
#     # message = "What is the capital of France?"
#     # print(ChatWithGemma3(message))

#     message = "Analyze this baby image and identify any signs of disease."
#     image = "demo/image/Neonatal_Jaundice-e1605866934597-2.jpg"
#     response = ChatWithGemma3WithImage(message, image)
#     print(response)
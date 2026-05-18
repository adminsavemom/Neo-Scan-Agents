import os
from llama_cpp import Llama

GGUF_PATH = "baby-gemma.gguf"


def load_model():

    if not os.path.exists(GGUF_PATH):
        raise Exception("GGUF file not found")

    llm = Llama(
        model_path=GGUF_PATH,
        n_ctx=2048,
        n_gpu_layers=-1,
        verbose=True
    )

    return llm


def chat(llm, prompt: str):

    response = llm.create_chat_completion(
        messages=[
            {
                "role": "user",
                "content": prompt
            }
        ]
    )

    return response["choices"][0]["message"]["content"]


def main():

    llm = load_model()

    output = chat(
        llm,
        "Explain quantum computing simply"
    )

    print(output)


if __name__ == "__main__":
    main()
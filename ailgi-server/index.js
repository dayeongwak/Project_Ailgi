const express = require("express");
const cors = require("cors");
const bodyParser = require("body-parser");
const fetch = require("node-fetch");

const app = express();
app.use(cors());
app.use(bodyParser.json());

// 👉 발급받은 Hugging Face API 키 (절대 코드에 직접 넣지 말고 환경변수로 관리 추천)
const HF_TOKEN = process.env.HF_TOKEN;

// ✅ /chat 엔드포인트
app.post("/chat", async (req, res) => {
  try {
    const userMessage = req.body.message;

    // Hugging Face Inference API (Mistral 모델 예시)
    const response = await fetch(
      "https://api-inference.huggingface.co/models/mistralai/Mistral-7B-Instruct-v0.2",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${HF_API_KEY}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          inputs: userMessage
        })
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      console.error("❌ Hugging Face API Error:", errorText);
      return res.status(500).json({ error: "Hugging Face API 호출 실패" });
    }

    const data = await response.json();
    console.log("✅ Hugging Face 응답:", data);

    res.json({ reply: data[0]?.generated_text || "응답 없음" });

  } catch (error) {
    console.error("❌ 서버 오류:", error);
    res.status(500).json({ error: error.message });
  }
});

// ✅ 서버 실행
app.listen(3000, () => {
  console.log("✅ Server running on http://localhost:3000");
});

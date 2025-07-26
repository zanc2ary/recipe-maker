import { RequestHandler } from "express";

export const getRecipeRecommendations: RequestHandler = async (req, res) => {
  try {
    const { ingredients } = req.body;
    
    if (!ingredients || !Array.isArray(ingredients)) {
      return res.status(400).json({ error: "Invalid ingredients array" });
    }

    // Call your Lambda API
    const response = await fetch('https://t34fhri733.execute-api.ap-southeast-2.amazonaws.com/prod/recommend', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ ingredients })
    });
    
    if (!response.ok) {
      throw new Error(`Lambda API error: ${response.status}`);
    }
    
    const data = await response.json();
    res.json(data);
    
  } catch (error) {
    console.error('Error calling Lambda API:', error);
    res.status(500).json({ error: "Failed to get recipe recommendations" });
  }
};

// Mock recipe data as fallback
const mockRecipeData = [
  {
    id: "1",
    name: "Garlic Ginger Stir-fry",
    ingredients: ["garlic", "ginger", "soy sauce", "oil", "vegetables"],
    instructions: [
      "Heat oil in a wok or large pan",
      "Add minced garlic and ginger, stir-fry for 30 seconds",
      "Add vegetables and stir-fry until tender-crisp",
      "Season with soy sauce and serve hot",
    ],
    tags: ["quick", "healthy", "asian"],
  },
  {
    id: "2",
    name: "Simple Seasoned Dish",
    ingredients: ["salt", "pepper", "herbs", "main ingredient"],
    instructions: [
      "Season ingredients with salt and pepper",
      "Add fresh herbs for flavor",
      "Cook until tender",
      "Adjust seasoning to taste",
    ],
    tags: ["simple", "classic", "versatile"],
  },
];

export const getRecipeRecommendations = async (req, res) => {
  try {
    const { ingredients } = req.body;

    if (!ingredients || !Array.isArray(ingredients)) {
      return res.status(400).json({ error: "Invalid ingredients array" });
    }

    console.log("Attempting to call Lambda API with ingredients:", ingredients);

    // Try to call your Lambda API
    try {
      const response = await fetch(
        "https://t34tfhi733.execute-api.ap-southeast-2.amazonaws.com/prod/recommend",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ ingredients }),
          // Add timeout to prevent hanging
          signal: AbortSignal.timeout(10000), // 10 second timeout
        },
      );

      if (!response.ok) {
        throw new Error(
          `Lambda API error: ${response.status} ${response.statusText}`,
        );
      }

      const data = await response.json();
      console.log("Lambda API success:", data);

      // Parse DynamoDB format to extract actual values
      const parsedRecipes = data.map((item) => ({
        id: item.id?.S || item.id,
        name: item.name?.S || item.name,
        ingredients: item.ingredients?.S
          ? item.ingredients.S.split(", ")
          : item.ingredients || [],
        instructions: item.instructions?.S
          ? item.instructions.S.split(". ").filter(Boolean)
          : item.instructions || [],
        tags: item.tags?.S ? item.tags.S.split(", ") : item.tags || [],
      }));

      console.log("Parsed recipes:", parsedRecipes);
      res.json(parsedRecipes);
      return;
    } catch (lambdaError) {
      console.error("Lambda API failed, using fallback:", lambdaError);

      // Use mock data as fallback
      const ingredientBasedRecipes = mockRecipeData.map((recipe, index) => ({
        ...recipe,
        id: `fallback-${index + 1}`,
        name: `${ingredients[0] ? ingredients[0].charAt(0).toUpperCase() + ingredients[0].slice(1) : "Ingredient"} Recipe ${index + 1}`,
        ingredients: [
          ...ingredients,
          ...recipe.ingredients.filter((ing) => !ingredients.includes(ing)),
        ],
      }));

      console.log("Returning fallback recipes:", ingredientBasedRecipes);
      res.json(ingredientBasedRecipes);
    }
  } catch (error) {
    console.error("Server error in recipe recommendations:", error);
    res
      .status(500)
      .json({
        error: "Failed to get recipe recommendations",
        details: error.message,
      });
  }
};

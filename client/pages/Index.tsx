import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { ChefHat, Plus, X, Sparkles, Clock, Users, Utensils } from "lucide-react";

interface Recipe {
  id: string;
  title: string;
  description: string;
  cookTime: string;
  servings: number;
  difficulty: "Easy" | "Medium" | "Hard";
  ingredients: string[];
  instructions: string[];
  tags: string[];
}

export default function Index() {
  const [ingredients, setIngredients] = useState<string[]>([]);
  const [currentIngredient, setCurrentIngredient] = useState("");
  const [generatedRecipes, setGeneratedRecipes] = useState<Recipe[]>([]);
  const [isGenerating, setIsGenerating] = useState(false);

  const addIngredient = () => {
    if (currentIngredient.trim() && !ingredients.includes(currentIngredient.trim())) {
      setIngredients([...ingredients, currentIngredient.trim()]);
      setCurrentIngredient("");
    }
  };

  const removeIngredient = (ingredient: string) => {
    setIngredients(ingredients.filter(i => i !== ingredient));
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === "Enter") {
      addIngredient();
    }
  };

  const generateRecipes = async () => {
    if (ingredients.length === 0) return;
    
    setIsGenerating(true);
    
    // Simulate API call - in real app, this would call your Lambda function
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Mock generated recipes based on ingredients
    const mockRecipes: Recipe[] = [
      {
        id: "1",
        title: `Delicious ${ingredients[0]} Bowl`,
        description: `A wholesome and flavorful dish featuring ${ingredients.join(", ")} with aromatic herbs and spices.`,
        cookTime: "25 mins",
        servings: 4,
        difficulty: "Easy",
        ingredients: [...ingredients, "olive oil", "salt", "pepper", "garlic"],
        instructions: [
          "Prep all your ingredients and wash them thoroughly",
          "Heat olive oil in a large pan over medium heat",
          "Add garlic and cook until fragrant",
          `Add ${ingredients.join(" and ")} to the pan`,
          "Season with salt and pepper to taste",
          "Cook for 15-20 minutes until tender",
          "Serve hot and enjoy!"
        ],
        tags: ["Healthy", "Quick", "One-Pan"]
      },
      {
        id: "2",
        title: `Gourmet ${ingredients[ingredients.length - 1]} Medley`,
        description: `An elevated take on classic flavors, combining ${ingredients.slice(0, 2).join(" and ")} in perfect harmony.`,
        cookTime: "40 mins",
        servings: 6,
        difficulty: "Medium",
        ingredients: [...ingredients, "fresh herbs", "white wine", "butter", "onion"],
        instructions: [
          "Prepare mise en place for all ingredients",
          "Sauté onions until translucent",
          "Add white wine and let reduce",
          `Incorporate ${ingredients.join(", ")} gradually`,
          "Finish with butter and fresh herbs",
          "Adjust seasoning and serve"
        ],
        tags: ["Gourmet", "Wine Pairing", "Comfort Food"]
      }
    ];
    
    setGeneratedRecipes(mockRecipes);
    setIsGenerating(false);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-orange-50 via-amber-50 to-yellow-50">
      {/* Header */}
      <header className="border-b bg-white/80 backdrop-blur-sm">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center gap-3">
            <div className="bg-primary rounded-full p-2">
              <ChefHat className="h-6 w-6 text-primary-foreground" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-foreground">RecipeAI</h1>
              <p className="text-sm text-muted-foreground">Turn your ingredients into amazing recipes</p>
            </div>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8">
        {/* Hero Section */}
        <div className="text-center mb-12">
          <h2 className="text-4xl md:text-6xl font-bold text-foreground mb-4">
            What's in your
            <span className="text-primary"> kitchen?</span>
          </h2>
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
            Tell us what ingredients you have, and we'll create personalized recipes just for you using AI magic.
          </p>
        </div>

        {/* Ingredient Input Section */}
        <Card className="max-w-3xl mx-auto mb-8 shadow-lg">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Utensils className="h-5 w-5" />
              Add Your Ingredients
            </CardTitle>
            <CardDescription>
              Start typing ingredients you have available and press Enter or click Add
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex gap-2">
              <Input
                placeholder="e.g., chicken, tomatoes, basil..."
                value={currentIngredient}
                onChange={(e) => setCurrentIngredient(e.target.value)}
                onKeyPress={handleKeyPress}
                className="flex-1"
              />
              <Button onClick={addIngredient} disabled={!currentIngredient.trim()}>
                <Plus className="h-4 w-4" />
                Add
              </Button>
            </div>
            
            {/* Ingredients List */}
            {ingredients.length > 0 && (
              <div className="space-y-3">
                <h4 className="font-medium text-sm text-muted-foreground">Your Ingredients:</h4>
                <div className="flex flex-wrap gap-2">
                  {ingredients.map((ingredient) => (
                    <Badge key={ingredient} variant="secondary" className="text-sm py-1 px-3">
                      {ingredient}
                      <button
                        onClick={() => removeIngredient(ingredient)}
                        className="ml-2 hover:text-destructive"
                      >
                        <X className="h-3 w-3" />
                      </button>
                    </Badge>
                  ))}
                </div>
                
                <Button 
                  onClick={generateRecipes} 
                  disabled={isGenerating || ingredients.length === 0}
                  className="w-full mt-4"
                  size="lg"
                >
                  {isGenerating ? (
                    <>
                      <Sparkles className="h-4 w-4 mr-2 animate-spin" />
                      Generating Recipes...
                    </>
                  ) : (
                    <>
                      <Sparkles className="h-4 w-4 mr-2" />
                      Generate Recipes
                    </>
                  )}
                </Button>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Generated Recipes */}
        {generatedRecipes.length > 0 && (
          <div className="max-w-6xl mx-auto">
            <h3 className="text-2xl font-bold text-center mb-8">
              Your Personalized Recipes
            </h3>
            <div className="grid md:grid-cols-2 gap-6">
              {generatedRecipes.map((recipe) => (
                <Card key={recipe.id} className="shadow-lg hover:shadow-xl transition-shadow">
                  <CardHeader>
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <CardTitle className="text-xl mb-2">{recipe.title}</CardTitle>
                        <CardDescription className="text-base">
                          {recipe.description}
                        </CardDescription>
                      </div>
                      <Badge variant={recipe.difficulty === "Easy" ? "secondary" : recipe.difficulty === "Medium" ? "default" : "destructive"}>
                        {recipe.difficulty}
                      </Badge>
                    </div>
                    
                    <div className="flex items-center gap-4 text-sm text-muted-foreground mt-3">
                      <div className="flex items-center gap-1">
                        <Clock className="h-4 w-4" />
                        {recipe.cookTime}
                      </div>
                      <div className="flex items-center gap-1">
                        <Users className="h-4 w-4" />
                        Serves {recipe.servings}
                      </div>
                    </div>
                  </CardHeader>
                  
                  <CardContent className="space-y-4">
                    <div>
                      <h5 className="font-medium mb-2">Ingredients:</h5>
                      <div className="flex flex-wrap gap-1">
                        {recipe.ingredients.map((ingredient, index) => (
                          <Badge key={index} variant="outline" className="text-xs">
                            {ingredient}
                          </Badge>
                        ))}
                      </div>
                    </div>
                    
                    <div>
                      <h5 className="font-medium mb-2">Instructions:</h5>
                      <ol className="text-sm space-y-1 text-muted-foreground">
                        {recipe.instructions.slice(0, 3).map((step, index) => (
                          <li key={index} className="flex">
                            <span className="font-medium text-primary mr-2">{index + 1}.</span>
                            {step}
                          </li>
                        ))}
                        {recipe.instructions.length > 3 && (
                          <li className="text-xs italic">
                            +{recipe.instructions.length - 3} more steps...
                          </li>
                        )}
                      </ol>
                    </div>
                    
                    <div className="flex flex-wrap gap-1 pt-2">
                      {recipe.tags.map((tag) => (
                        <Badge key={tag} variant="secondary" className="text-xs">
                          {tag}
                        </Badge>
                      ))}
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
        )}

        {/* Empty State */}
        {ingredients.length === 0 && (
          <div className="text-center py-12">
            <div className="bg-primary/10 rounded-full w-20 h-20 flex items-center justify-center mx-auto mb-4">
              <ChefHat className="h-10 w-10 text-primary" />
            </div>
            <p className="text-muted-foreground max-w-md mx-auto">
              Start by adding ingredients you have in your kitchen. Our AI will suggest delicious recipes you can make right now!
            </p>
          </div>
        )}
      </main>
    </div>
  );
}

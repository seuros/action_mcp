# frozen_string_literal: true

class CarbonFootprintAssessmentPrompt < ApplicationMCPPrompt
  description "Guide for assessing and reducing personal carbon footprint"

  argument :transportation_method, description: "Primary mode of transportation", required: true
  argument :household_size, description: "Number of people in household", required: true
  argument :diet_type, description: "Dietary preference (omnivore, vegetarian, vegan, etc.)", required: true
  argument :location_type, description: "Urban, suburban, or rural living environment", required: false

  def perform
    location = location_type || "your area"

    # Initial user inquiry
    render(text: "I'd like to understand my carbon footprint better. I primarily use #{transportation_method} for getting around, live with #{household_size} people, and follow a #{diet_type} diet in #{location}.")

    # Assistant's initial assessment
    render(
      text: "Thank you for your interest in understanding your carbon footprint. Based on your #{transportation_method} use, #{household_size}-person household, and #{diet_type} diet in #{location}, I can provide some initial insights. Would you like to start with transportation, home energy, or food consumption?", role: :assistant
    )

    # User selects area to focus on
    render(text: "Let's start with transportation since I use #{transportation_method}.")

    # Assistant transportation analysis
    transportation_guidance = case transportation_method.downcase
    when /car/, /automobile/, /vehicle/
                                "personal vehicle usage contributes significantly to individual carbon footprints. Consider carpooling, combining trips, or exploring public transit options when possible."
    when /bus/, /train/, /subway/, /public/
                                "public transportation is generally more sustainable than individual vehicles. You're already making a positive impact!"
    when /bike/, /walk/, /cycle/
                                "walking or cycling produces minimal carbon emissions. Your transportation choices are already very sustainable!"
    else
                                "analyzing your transportation method (#{transportation_method}) for sustainability."
    end

    render(
      text: "Looking at your transportation habits, #{transportation_guidance} Would you be interested in some specific strategies to further reduce your transportation-related emissions?", role: :assistant
    )

    # User expresses interest in recommendations
    render(text: "Yes, I'd like to learn some strategies to improve.")

    # Assistant provides recommendations
    render(
      text: "Here are some sustainable transportation strategies to consider:\n\n1. For short trips under 2 miles, consider walking or biking when possible\n2. Explore carpooling options for regular commutes\n3. Plan and combine errands to reduce total trips\n4. Consider remote work options if available for your profession\n5. When replacing your vehicle, research electric or hybrid options\n\nWould you like to discuss home energy usage or food choices next?", role: :assistant
    )

    # User chooses next topic
    render(text: "Let's talk about diet and food choices since I follow a #{diet_type} diet.")

    # Assistant diet analysis
    diet_guidance = case diet_type.downcase
    when /vegan/
                      "a vegan diet typically has the lowest carbon footprint among dietary choices. Your plant-based diet is already making a significant positive impact!"
    when /vegetarian/
                      "a vegetarian diet generally has a lower carbon footprint than omnivorous diets. Your choice to avoid meat helps reduce emissions associated with livestock production."
    when /omnivore/, /meat/
                      "incorporating more plant-based meals can help reduce your diet's carbon footprint. Even small changes like meat-free days can make a difference."
    else
                      "different food choices can significantly affect your carbon footprint. Generally, plant-based foods have lower environmental impacts than animal products."
    end

    # Final assistant message
    render(
      text: "Regarding your #{diet_type} diet, #{diet_guidance} Food choices have a substantial environmental impact, with about 25% of global emissions coming from food systems. Would you like some specific recommendations for sustainable food practices based on your diet?", role: :assistant
    )
  end
end

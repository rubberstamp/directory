namespace :pages do
  desc "Migrate events page to the CMS"
  task migrate_events: :environment do
    if defined?(Page)
      # Read the content template
      template_path = Rails.root.join("app/views/admin/pages/content_templates/_events.html.erb")
      if File.exist?(template_path)
        events_content = File.read(template_path)

        # Create the Events page
        page = Page.find_or_initialize_by(slug: "events")
        page.assign_attributes({
          title: "Fractional CFO Events",
          content: events_content,
          meta_description: "Join our monthly Fractional CFO Mastermind sessions for collaboration, networking, and problem-solving among finance professionals.",
          meta_keywords: "fractional cfo, mastermind, cfo events, finance networking",
          published: true,
          show_in_menu: true,
          position: 50
        })

        if page.save
          puts "Events page created/updated successfully!"
        else
          puts "Error creating Events page: #{page.errors.full_messages.join(', ')}"
        end
      else
        puts "Events template not found at #{template_path}"
      end
    else
      puts "Page model not defined. Ensure CMS migration has been run."
    end
  end

  desc "Migrate about page to the CMS"
  task migrate_about: :environment do
    if defined?(Page)
      # Read the content template
      template_path = Rails.root.join("app/views/admin/pages/content_templates/_about.html.erb")
      if File.exist?(template_path)
        about_content = File.read(template_path)

        # Create the About page
        page = Page.find_or_initialize_by(slug: "about")
        page.assign_attributes({
          title: "About The Gross Profit Podcast",
          content: about_content,
          meta_description: "Learn how The Gross Profit Podcast connects finance professionals with businesses that need their expertise.",
          meta_keywords: "gross profit podcast, james kennedy, fractional cfo, podcast about, finance podcast",
          published: true,
          show_in_menu: true,
          position: 40
        })

        if page.save
          puts "About page created/updated successfully!"
        else
          puts "Error creating About page: #{page.errors.full_messages.join(', ')}"
        end
      else
        puts "About template not found at #{template_path}"
      end
    else
      puts "Page model not defined. Ensure CMS migration has been run."
    end
  end

  desc "Create a sample CFO quiz page"
  task create_cfo_quiz: :environment do
    if defined?(Page)
      cfo_quiz_content = <<-HTML
<div class="quiz-container bg-white p-6 sm:p-8 rounded-lg shadow-xl max-w-2xl w-full mx-auto">
  <div class="mb-6">
    <div class="flex justify-between items-center mb-1 text-sm font-medium text-gray-600">
      <span>Progress</span>
      <span id="progressText">Question 0 of 9</span>
    </div>
    <div class="w-full bg-gray-200 rounded-full h-2.5">
      <div id="progressBar" class="bg-blue-600 h-2.5 rounded-full transition-all duration-500 ease-out" style="width: 0%"></div>
    </div>
  </div>

  <div class="quiz-card active" id="card-0">
    <h2 class="text-2xl font-bold text-gray-800 mb-4">Is Your Business Ready for a CFO?</h2>
    <p class="text-gray-600 mb-6 leading-relaxed">Knowing when to bring in high-level financial expertise is crucial for growth. Answer these questions to understand if your needs point towards a Bookkeeper, Controller, or a strategic CFO (Fractional or Full-Time).</p>
    <button class="w-full sm:w-auto bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-6 rounded-lg transition duration-300 ease-in-out" onclick="nextQuestion(1)">Start Quiz</button>
  </div>

  <div class="quiz-card hidden" id="card-1">
    <h3 class="text-xl font-semibold text-gray-800 mb-5">1. How are your day-to-day finances currently managed?</h3>
    <div class="space-y-3 mb-6">
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
        <input type="radio" name="q1" value="A" id="q1a" onclick="selectAnswer(1, 'A')">
        <label for="q1a" class="text-gray-700">I (the owner) handle most bookkeeping and financial tasks.</label>
      </div>
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
        <input type="radio" name="q1" value="B" id="q1b" onclick="selectAnswer(1, 'B')">
        <label for="q1b" class="text-gray-700">We have a part-time or full-time bookkeeper handling data entry and basic reconciliation.</label>
      </div>
       <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
        <input type="radio" name="q1" value="C" id="q1c" onclick="selectAnswer(1, 'C')">
        <label for="q1c" class="text-gray-700">We have an internal or external accountant/controller managing reporting and processes.</label>
      </div>
    </div>
    <button id="button-1" class="w-full sm:w-auto bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-6 rounded-lg transition duration-300 ease-in-out opacity-50 cursor-not-allowed" onclick="nextQuestion(2)" disabled>Next</button>
  </div>

  <div class="quiz-card hidden" id="card-2">
    <h3 class="text-xl font-semibold text-gray-800 mb-5">2. How do you use your financial reports?</h3>
    <div class="space-y-3 mb-6">
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
        <input type="radio" name="q2" value="A" id="q2a" onclick="selectAnswer(2, 'A')">
        <label for="q2a" class="text-gray-700">Mainly for tax compliance and basic P&L overview.</label>
      </div>
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
        <input type="radio" name="q2" value="B" id="q2b" onclick="selectAnswer(2, 'B')">
        <label for="q2b" class="text-gray-700">To track budget vs. actuals, manage cash flow, and ensure accuracy.</label>
      </div>
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
        <input type="radio" name="q2" value="C" id="q2c" onclick="selectAnswer(2, 'C')">
        <label for="q2c" class="text-gray-700">For deep analysis, identifying KPIs, forecasting future performance, and making strategic decisions.</label>
      </div>
    </div>
    <button id="button-2" class="w-full sm:w-auto bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-6 rounded-lg transition duration-300 ease-in-out opacity-50 cursor-not-allowed" onclick="nextQuestion(3)" disabled>Next</button>
  </div>

  <div class="quiz-card hidden" id="card-3">
    <h3 class="text-xl font-semibold text-gray-800 mb-5">3. How much time do you spend on forward-looking financial planning?</h3>
    <div class="space-y-3 mb-6">
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q3" value="A" id="q3a" onclick="selectAnswer(3, 'A')">
         <label for="q3a" class="text-gray-700">Very little; mostly focused on day-to-day operations.</label>
      </div>
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q3" value="B" id="q3b" onclick="selectAnswer(3, 'B')">
         <label for="q3b" class="text-gray-700">We create an annual budget, maybe some basic cash flow projections.</label>
      </div>
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q3" value="C" id="q3c" onclick="selectAnswer(3, 'C')">
         <label for="q3c" class="text-gray-700">We regularly develop detailed financial models, forecasts, scenario plans, and track key strategic metrics.</label>
      </div>
    </div>
    <button id="button-3" class="w-full sm:w-auto bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-6 rounded-lg transition duration-300 ease-in-out opacity-50 cursor-not-allowed" onclick="nextQuestion(4)" disabled>Next</button>
  </div>

  <div class="quiz-card hidden" id="card-4">
    <h3 class="text-xl font-semibold text-gray-800 mb-5">4. When making major business decisions, how is financial input integrated?</h3>
    <div class="space-y-3 mb-6">
       <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q4" value="A" id="q4a" onclick="selectAnswer(4, 'A')">
         <label for="q4a" class="text-gray-700">Mostly based on gut feel or operational needs; limited financial analysis.</label>
      </div>
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q4" value="B" id="q4b" onclick="selectAnswer(4, 'B')">
         <label for="q4b" class="text-gray-700">We look at basic cost/benefit, but struggle to model long-term financial impact.</label>
      </div>
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q4" value="C" id="q4c" onclick="selectAnswer(4, 'C')">
         <label for="q4c" class="text-gray-700">Financial modeling, ROI analysis, and risk assessment are core parts of our decision-making process.</label>
      </div>
    </div>
    <button id="button-4" class="w-full sm:w-auto bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-6 rounded-lg transition duration-300 ease-in-out opacity-50 cursor-not-allowed" onclick="nextQuestion(5)" disabled>Next</button>
  </div>

  <div class="quiz-card hidden" id="card-5">
    <h3 class="text-xl font-semibold text-gray-800 mb-5">5. Are you planning for significant scaling, seeking external funding, or considering M&A?</h3>
    <div class="space-y-3 mb-6">
       <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q5" value="A" id="q5a" onclick="selectAnswer(5, 'A')">
         <label for="q5a" class="text-gray-700">No, focusing on stable operations or organic growth.</label>
      </div>
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q5" value="B" id="q5b" onclick="selectAnswer(5, 'B')">
         <label for="q5b" class="text-gray-700">Maybe considering a bank loan or moderate expansion.</label>
      </div>
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q5" value="C" id="q5c" onclick="selectAnswer(5, 'C')">
         <label for="q5c" class="text-gray-700">Yes, actively planning for rapid growth, seeking venture capital/private equity, or exploring acquisitions/sale.</label>
      </div>
    </div>
    <button id="button-5" class="w-full sm:w-auto bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-6 rounded-lg transition duration-300 ease-in-out opacity-50 cursor-not-allowed" onclick="nextQuestion(6)" disabled>Next</button>
  </div>

  <div class="quiz-card hidden" id="card-6">
    <h3 class="text-xl font-semibold text-gray-800 mb-5">6. How complex are your financial operations and risks?</h3>
     <div class="space-y-3 mb-6">
       <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q6" value="A" id="q6a" onclick="selectAnswer(6, 'A')">
         <label for="q6a" class="text-gray-700">Fairly straightforward: single currency, simple revenue streams, basic operational risks.</label>
      </div>
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q6" value="B" id="q6b" onclick="selectAnswer(6, 'B')">
         <label for="q6b" class="text-gray-700">Moderately complex: maybe inventory management, multiple bank accounts, standard contracts, need for internal controls.</label>
      </div>
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q6" value="C" id="q6c" onclick="selectAnswer(6, 'C')">
         <label for="q6c" class="text-gray-700">Highly complex: multi-currency, complex revenue recognition, international operations, significant financial/market risks, investor relations.</label>
      </div>
    </div>
    <button id="button-6" class="w-full sm:w-auto bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-6 rounded-lg transition duration-300 ease-in-out opacity-50 cursor-not-allowed" onclick="nextQuestion(7)" disabled>Next</button>
  </div>

  <div class="quiz-card hidden" id="card-7">
     <h3 class="text-xl font-semibold text-gray-800 mb-5">7. What's your biggest financial frustration or blind spot?</h3>
     <div class="space-y-3 mb-6">
       <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q7" value="A" id="q7a" onclick="selectAnswer(7, 'A')">
         <label for="q7a" class="text-gray-700">Keeping up with transaction recording and basic paperwork.</label>
      </div>
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q7" value="B" id="q7b" onclick="selectAnswer(7, 'B')">
         <label for="q7b" class="text-gray-700">Getting accurate reports on time, managing cash flow effectively, ensuring compliance.</label>
      </div>
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q7" value="C" id="q7c" onclick="selectAnswer(7, 'C')">
         <label for="q7c" class="text-gray-700">Lack of strategic financial insight, inability to forecast reliably, uncertainty about optimizing profitability/valuation.</label>
      </div>
    </div>
     <button id="button-7" class="w-full sm:w-auto bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-6 rounded-lg transition duration-300 ease-in-out opacity-50 cursor-not-allowed" onclick="nextQuestion(8)" disabled>Next</button>
  </div>

  <div class="quiz-card hidden" id="card-8">
     <h3 class="text-xl font-semibold text-gray-800 mb-5">8. What is your approximate annual revenue?</h3>
     <div class="space-y-3 mb-6">
       <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q8" value="A" id="q8a" onclick="selectAnswer(8, 'A')">
         <label for="q8a" class="text-gray-700">Under $1 Million</label>
      </div>
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q8" value="B" id="q8b" onclick="selectAnswer(8, 'B')">
         <label for="q8b" class="text-gray-700">$1 Million - $5 Million</label>
      </div>
      <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q8" value="C" id="q8c" onclick="selectAnswer(8, 'C')">
         <label for="q8c" class="text-gray-700">$5 Million - $20 Million</label>
      </div>
       <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q8" value="D" id="q8d" onclick="selectAnswer(8, 'D')">
         <label for="q8d" class="text-gray-700">Over $20 Million</label>
      </div>
    </div>
     <button id="button-8" class="w-full sm:w-auto bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-6 rounded-lg transition duration-300 ease-in-out opacity-50 cursor-not-allowed" onclick="nextQuestion(9)" disabled>Next</button>
  </div>

  <div class="quiz-card hidden" id="card-9">
     <h3 class="text-xl font-semibold text-gray-800 mb-5">9. Which category best describes your industry?</h3>
     <div class="space-y-3 mb-6">
       <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q9" value="A" id="q9a" onclick="selectAnswer(9, 'A')">
         <label for="q9a" class="text-gray-700">Services (Consulting, Agency, Professional Services)</label>
       </div>
       <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q9" value="B" id="q9b" onclick="selectAnswer(9, 'B')">
         <label for="q9b" class="text-gray-700">Retail / E-commerce / Consumer Goods</label>
       </div>
       <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q9" value="C" id="q9c" onclick="selectAnswer(9, 'C')">
         <label for="q9c" class="text-gray-700">SaaS / Technology / Software</label>
       </div>
        <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q9" value="D" id="q9d" onclick="selectAnswer(9, 'D')">
         <label for="q9d" class="text-gray-700">Manufacturing / Construction / Logistics</label>
       </div>
        <div class="answer-option border border-gray-300 rounded-lg p-4 hover:bg-gray-50 transition duration-200">
         <input type="radio" name="q9" value="E" id="q9e" onclick="selectAnswer(9, 'E')">
         <label for="q9e" class="text-gray-700">Other / Non-Profit</label>
       </div>
    </div>
     <button id="button-9" class="w-full sm:w-auto bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-6 rounded-lg transition duration-300 ease-in-out opacity-50 cursor-not-allowed" onclick="showResults()" disabled>See Results</button>
  </div>


  <div class="quiz-card hidden" id="results-card">
    <h2 class="text-2xl font-bold text-gray-800 mb-4">Your Financial Leadership Needs:</h2>

    <div class="mb-6">
      <label class="block text-sm font-medium text-gray-700 mb-1" id="gaugeLabel">CFO Readiness:</label>
      <div class="gauge-container">
        <div id="gaugeBar" class="gauge-bar" style="width: 0%;">
          <span id="gaugeText" class="relative px-2">0%</span>
        </div>
      </div>
    </div>

    <div id="results-content" class="text-gray-700 mb-6 space-y-3">
      </div>

    <div class="results-cta border-t pt-6 mt-6">
      <h4 class="text-lg font-semibold text-gray-800 mb-3">Next Steps & Resources:</h4>
      <p class="text-gray-600 mb-4">Gain deeper insights by exploring these resources:</p>
      <div class="space-y-2" id="cta-links">
        <a href="#" class="text-blue-600 hover:text-blue-800 hover:underline block">Placeholder Link 1</a>
        <a href="#" class="text-blue-600 hover:text-blue-800 hover:underline block">Placeholder Link 2</a>
      </div>
      <button class="mt-6 w-full sm:w-auto bg-gray-500 hover:bg-gray-600 text-white font-bold py-2 px-6 rounded-lg transition duration-300 ease-in-out" onclick="restartQuiz()">Restart Quiz</button>
    </div>
  </div>
</div>

<style>
/* Custom style for selected answer */
.selected-answer {
    border-color: #3b82f6; /* blue-500 */
    background-color: #eff6ff; /* blue-50 */
    /* Use ring for a subtle outer glow effect */
    --tw-ring-color: #3b82f6;
     box-shadow: var(--tw-ring-inset) 0 0 0 calc(2px + var(--tw-ring-offset-width)) var(--tw-ring-color);

}
/* Basic fade transition (can be enhanced) */
.quiz-card {
    transition: opacity 0.3s ease-in-out;
}
/* Hide radio button visually but keep it accessible */
.answer-option input[type="radio"] {
    position: absolute;
    opacity: 0;
    width: 0;
    height: 0;
}
/* Style the label/div as the clickable element */
.answer-option label {
    display: block;
    width: 100%;
    cursor: pointer;
}
/* Gauge Styles */
.gauge-container {
    background-color: #e5e7eb; /* gray-200 */
    border-radius: 9999px; /* rounded-full */
    height: 1rem; /* h-4 */
    overflow: hidden; /* Ensure inner bar stays contained */
    position: relative; /* For potential text overlay */
}
.gauge-bar {
    background-color: #2563eb; /* blue-600 */
    height: 100%;
    border-radius: 9999px; /* rounded-full */
    transition: width 0.5s ease-in-out; /* Animate width change */
    text-align: center;
    color: white;
    font-size: 0.75rem; /* text-xs */
    line-height: 1rem; /* Match height */
}
/* Style for the primary CTA link */
.cta-primary {
    font-weight: 600; /* semibold */
    /* Add other styles to make it stand out if desired */
}
</style>

<script>
let currentQuestion = 0;
const totalQuestions = 9; // Updated total questions
const answers = {}; // Object to store answers {1: 'A', ..., 8: 'C', 9: 'B'}

// Function called when an answer option is clicked
function selectAnswer(questionIndex, value) {
    answers[questionIndex] = value;

    // Visually mark the selected answer
    const answerOptions = document.querySelectorAll(`#card-\${questionIndex} .answer-option`);
    answerOptions.forEach(opt => {
        // Remove selection style from all within the current question card
        opt.classList.remove('selected-answer');
         // Reset border and background explicitly if needed
         opt.style.borderColor = '';
         opt.style.backgroundColor = '';
    });

    // Find the parent div of the clicked radio button and add style
    const selectedRadio = document.getElementById(`q\${questionIndex}\${value.toLowerCase()}`);
    if (selectedRadio) {
         const parentDiv = selectedRadio.closest('.answer-option');
         parentDiv.classList.add('selected-answer');
    }

    // Enable the 'Next' or 'See Results' button for the current question
    const nextButton = document.getElementById(`button-\${questionIndex}`);
    if (nextButton) {
        nextButton.disabled = false;
        nextButton.classList.remove('opacity-50', 'cursor-not-allowed');
    }
}

// Function to move to the next question
function nextQuestion(nextIndex) {
    // Basic validation - ensure an answer is selected for the current question before proceeding
    if (currentQuestion > 0 && !answers[currentQuestion]) {
        // Optionally show an error message
        // alert("Please select an answer before proceeding.");
        return;
    }

    // Hide current card
    const currentCard = document.getElementById(`card-\${currentQuestion}`);
    if (currentCard) {
        currentCard.classList.add('hidden');
        currentCard.classList.remove('active');
    }

    // Show next card
    const nextCard = document.getElementById(`card-\${nextIndex}`);
    if (nextCard) {
        nextCard.classList.remove('hidden');
        nextCard.classList.add('active');
        currentQuestion = nextIndex;
        updateProgressBar();
    } else {
        console.error("Next card index not found:", nextIndex);
    }
}

// Function to update the progress bar visuals and text
function updateProgressBar() {
    // Calculate progress based on starting from question 1
    const progress = currentQuestion > 0 ? (currentQuestion / totalQuestions) * 100 : 0;
    const progressBar = document.getElementById('progressBar');
    const progressText = document.getElementById('progressText');

    progressBar.style.width = `\${progress}%`;
    // Update text only when quiz starts
    progressText.innerText = currentQuestion > 0 ? `Question \${currentQuestion} of \${totalQuestions}` : `Question 0 of \${totalQuestions}`;
}

// --- Constants for Scoring ---
const CFO_THRESHOLD = 8; // Score needed to be considered for CFO
const CONTROLLER_THRESHOLD = 5; // Score needed for Controller consideration
const REVENUE_THRESHOLD_FT = 'C'; // $5M+ (Answers C or D) might lean towards Full-Time
const COMPLEX_INDUSTRY_WEIGHT = 1; // Add weight for complex industries (C, D)

// Function to calculate score and display results
function showResults() {
     // Final validation check
     if (!answers[currentQuestion]) {
         return;
     }

    // Hide the last question card
    const lastQuestionCard = document.getElementById(`card-\${totalQuestions}`);
    if (lastQuestionCard) {
        lastQuestionCard.classList.add('hidden');
        lastQuestionCard.classList.remove('active');
    }

    // Show the results card
    const resultsCard = document.getElementById('results-card');
    if (resultsCard) {
        resultsCard.classList.remove('hidden');
    }

     // --- Scoring Logic ---
    let scoreCFO = 0;
    let scoreController = 0;
    let scoreBookkeeper = 0;

    // Iterate through answers for Q1-Q7 and assign points
    for (let q = 1; q <= 7; q++) {
        const answer = answers[q];
        const questionNum = q;

        if (!answer) continue; // Skip if a question was somehow missed

        if (answer === 'C') {
            if ([2, 3, 4, 5, 6, 7].includes(questionNum)) scoreCFO += 2; else scoreCFO += 1;
            if (questionNum === 5) scoreCFO += 1; // Extra weight for Funding/M&A
            if (questionNum === 7) scoreCFO += 1; // Extra weight for Strategic Blind Spot
        } else if (answer === 'B') {
            if ([1, 2, 6, 7].includes(questionNum)) scoreController += 2; else scoreController += 1;
            if (questionNum === 7) scoreController += 1; // Extra weight for Accuracy/Cash Flow Issues
        } else { // Answer 'A'
            if ([1, 7].includes(questionNum)) scoreBookkeeper += 2; else scoreBookkeeper += 1;
        }
    }

    // --- Determine Result Category ---
    let resultCategory = 'Bookkeeper'; // Default
    if (scoreCFO >= CFO_THRESHOLD) {
        resultCategory = 'CFO';
    } else if (scoreController >= CONTROLLER_THRESHOLD) {
        resultCategory = 'Controller';
    }

    // --- Refine CFO Recommendation (Fractional vs. Full-Time) ---
    let cfoType = 'Fractional'; // Default if CFO category is met
    let cfoReadinessScore = 0; // For the gauge (0-100)

    if (resultCategory === 'CFO') {
        const revenue = answers[8]; // A, B, C, D
        const industry = answers[9]; // A, B, C, D, E
        let fullTimeLean = 0;

        // Revenue Factor: Higher revenue leans towards FT
        if (revenue === 'C') fullTimeLean += 1; // $5M - $20M
        if (revenue === 'D') fullTimeLean += 2; // Over $20M

        // Complexity Factor (Q6=C) leans towards FT
        if (answers[6] === 'C') fullTimeLean += 1;

         // Funding/M&A Factor (Q5=C) leans strongly towards FT
        if (answers[5] === 'C') fullTimeLean += 2;

        // Industry Factor: Complex industries lean towards FT
        if (['C', 'D'].includes(industry)) { // SaaS/Tech, Manufacturing/Logistics
            fullTimeLean += COMPLEX_INDUSTRY_WEIGHT;
        }

        // High CFO Score leans towards FT
        if (scoreCFO >= CFO_THRESHOLD + 3) { // e.g., score of 11+
            fullTimeLean +=1;
        }

        // Decision: If enough factors point to FT needs
        if (fullTimeLean >= 4) { // Adjust this threshold as needed
            cfoType = 'Full-Time';
        }

        // Calculate Gauge Score (example: scale CFO score to 100 max)
        // Max possible CFO score based on logic is around 13-15. Let's cap at 12 for scaling.
         cfoReadinessScore = Math.min(100, Math.round((scoreCFO / 12) * 100));
         if (cfoType === 'Full-Time') {
            cfoReadinessScore = Math.max(75, cfoReadinessScore); // Ensure FT shows high readiness
         } else {
            // Fractional might range from 50-85 readiness
            cfoReadinessScore = Math.max(50, Math.min(85, cfoReadinessScore));
         }

    } else if (resultCategory === 'Controller') {
         // Lower readiness score for Controller need
         cfoReadinessScore = Math.min(50, Math.round((scoreController / (CONTROLLER_THRESHOLD + 3)) * 50)); // Scale controller score to max 50%
         cfoReadinessScore = Math.max(25, cfoReadinessScore); // Min 25% for controller
    } else {
         // Lowest readiness score for Bookkeeper need
         cfoReadinessScore = Math.min(25, Math.round((scoreBookkeeper / 5) * 25)); // Scale bookkeeper score to max 25%
         cfoReadinessScore = Math.max(5, cfoReadinessScore); // Min 5%
    }


    // --- Update Gauge ---
    const gaugeBar = document.getElementById('gaugeBar');
    const gaugeText = document.getElementById('gaugeText');
    const gaugeLabel = document.getElementById('gaugeLabel');

    gaugeBar.style.width = `\${cfoReadinessScore}%`;
    gaugeText.innerText = `\${cfoReadinessScore}%`;
    if (cfoReadinessScore < 30) {
         gaugeBar.classList.remove('bg-blue-600', 'bg-yellow-500');
         gaugeBar.classList.add('bg-red-500'); // Low readiness
         gaugeLabel.innerText = "Focus on Foundational Needs:";
    } else if (cfoReadinessScore < 65) {
         gaugeBar.classList.remove('bg-blue-600', 'bg-red-500');
         gaugeBar.classList.add('bg-yellow-500'); // Medium readiness (Controller/Early Fractional)
         gaugeLabel.innerText = "Controller / Fractional CFO Readiness:";
    } else {
         gaugeBar.classList.remove('bg-yellow-500', 'bg-red-500');
         gaugeBar.classList.add('bg-blue-600'); // High readiness (Strong Fractional/Full-Time)
         gaugeLabel.innerText = "Strong CFO Readiness:";
    }


    // --- Generate Result Text and CTAs ---
    let resultTitle = "";
    let resultText = "";
    let ctaLinksHTML = "";

    // Define the new CTA link
    const mapLink = `<a href="https://grossprofitpodcast.com/map" target="_blank" class="text-blue-600 hover:text-blue-800 hover:underline block cta-primary">Find a Fractional CFO Near You</a>`;


    switch (resultCategory) {
        case 'CFO':
            if (cfoType === 'Full-Time') {
                resultTitle = "Strong Need for a Full-Time CFO";
                resultText = `<p>Your combination of strategic needs, revenue level, complexity, and growth trajectory strongly suggests the need for a dedicated, Full-Time CFO. They will be integral to navigating complex financial landscapes, securing funding, managing risk, and driving strategic decisions daily.</p>
                              <p><strong>Key Indicators:</strong> High strategic focus, significant revenue/scaling, complex operations/industry, active funding/M&A, critical need for daily financial leadership.</p>`;
                // Full-Time result CTAs
                ctaLinksHTML = `
                    <a href="#" class="text-blue-600 hover:text-blue-800 hover:underline block">Read: What to Expect from a Full-Time CFO</a>
                    <a href="#" class="text-blue-600 hover:text-blue-800 hover:underline block">Listen: Hiring Your Full-Time CFO (Episode Link)</a>
                    <a href="#" class="text-blue-600 hover:text-blue-800 hover:underline block">Listen: Advanced Financial Strategy for Scale (Episode Link)</a>`;
                    // Optionally add map link here too, but less prominent
                    // ctaLinksHTML += mapLink.replace('cta-primary', ''); // Add without primary styling
            } else { // Fractional CFO
                resultTitle = "Ready for a Fractional CFO";
                resultText = `<p>Your answers indicate a clear need for strategic financial guidance beyond day-to-day accounting. A Fractional CFO can provide expert-level forecasting, analysis, and strategic planning on a part-time basis, fitting your current scale and needs.</p>
                              <p><strong>Key Indicators:</strong> Need for strategic insight & planning, moderate complexity/revenue, desire for growth optimization, but perhaps not requiring daily CFO involvement yet.</p>`;
                // Fractional result CTAs - Make Map Link Primary
                ctaLinksHTML = `
                    \${mapLink} <a href="#" class="text-blue-600 hover:text-blue-800 hover:underline block">Read: How Fractional CFOs Drive Profitability</a>
                    <a href="#" class="text-blue-600 hover:text-blue-800 hover:underline block">Listen: The Power of a Fractional CFO (Episode Link)</a>
                    <a href="#" class="text-blue-600 hover:text-blue-800 hover:underline block">Listen: Building Your First Strategic Financial Plan (Episode Link)</a>`;
            }
            break; // End CFO Case

        case 'Controller':
            resultTitle = "Potential Need for a Controller";
            resultText = `<p>Your business seems to require stronger financial controls, more robust reporting, and efficient process management. A Controller can ensure financial accuracy, manage cash flow effectively, and oversee bookkeeping functions, setting the stage for future strategic finance.</p>
                          <p><strong>Key Indicators:</strong> Need for accurate/timely reports, managing budget vs. actuals, cash flow concerns, moderate complexity, process improvement focus.</p>`;
            // Controller result CTAs - Include Map Link
            ctaLinksHTML = `
                <a href="#" class="text-blue-600 hover:text-blue-800 hover:underline block">Read: Implementing Strong Internal Controls</a>
                <a href="#" class="text-blue-600 hover:text-blue-800 hover:underline block">Listen: Controller vs. CFO - What's the Difference? (Episode Link)</a>
                <a href="#" class="text-blue-600 hover:text-blue-800 hover:underline block">Listen: Mastering Your Month-End Close (Episode Link)</a>
                \${mapLink.replace('cta-primary', '')} `;
            break; // End Controller Case

        default: // Bookkeeper
            resultTitle = "Focus on Bookkeeping & Foundational Accounting";
            resultText = `<p>Your current needs seem centered around accurate transaction recording and basic financial organization. Ensure you have solid bookkeeping practices in place, either handled efficiently by yourself or a dedicated bookkeeper. This is the essential foundation.</p>
                          <p><strong>Key Indicators:</strong> Time spent on basic data entry, need for simple P&L, focus on past transaction accuracy, lower complexity.</p>`;
            // Bookkeeper result CTAs
            ctaLinksHTML = `
                <a href="#" class="text-blue-600 hover:text-blue-800 hover:underline block">Read: Essential Bookkeeping Habits for Owners</a>
                <a href="#" class="text-blue-600 hover:text-blue-800 hover:underline block">Listen: Choosing the Right Bookkeeping Software (Episode Link)</a>`;
            break; // End Default Case
    }


    // Display the results
    const resultsContent = document.getElementById('results-content');
    const ctaLinksContainer = document.getElementById('cta-links');
    resultsContent.innerHTML = `<h3 class="text-xl font-semibold text-gray-800 mb-3">\${resultTitle}</h3>\${resultText}`;
    ctaLinksContainer.innerHTML = ctaLinksHTML; // Add dynamic links
}

// Function to restart the quiz
function restartQuiz() {
    // Reset answers and current question index
     Object.keys(answers).forEach(key => delete answers[key]);
     currentQuestion = 0;

     // Hide results card and all question cards except the intro
     document.getElementById('results-card').classList.add('hidden');
     const questionCards = document.querySelectorAll('.quiz-card[id^="card-"]');
     questionCards.forEach((card, index) => {
         if (index === 0) { // Show intro card
             card.classList.remove('hidden');
             card.classList.add('active');
         } else {
             card.classList.add('hidden');
             card.classList.remove('active');
         }
     });

     // Reset progress bar
     updateProgressBar(); // Will set text to Q0 and width to 0%

    // Reset gauge
    const gaugeBar = document.getElementById('gaugeBar');
    const gaugeText = document.getElementById('gaugeText');
    const gaugeLabel = document.getElementById('gaugeLabel');
    gaugeBar.style.width = '0%';
    gaugeText.innerText = '0%';
    gaugeLabel.innerText = 'CFO Readiness:';
     gaugeBar.classList.remove('bg-yellow-500', 'bg-red-500'); // Reset color
     gaugeBar.classList.add('bg-blue-600');


     // Reset radio buttons and button states
     const radioButtons = document.querySelectorAll('input[type="radio"]');
     radioButtons.forEach(radio => radio.checked = false);
     const nextButtons = document.querySelectorAll('button[id^="button-"]');
     nextButtons.forEach(button => {
         button.disabled = true;
         button.classList.add('opacity-50', 'cursor-not-allowed');
     });
     const answerDivs = document.querySelectorAll('.answer-option');
     answerDivs.forEach(div => {
        div.classList.remove('selected-answer');
        div.style.borderColor = '';
        div.style.backgroundColor = '';
     });
}

// Initialize progress bar text on load
document.addEventListener('DOMContentLoaded', () => {
     updateProgressBar();
});
</script>
      HTML

      # Create the CFO Quiz page
      page = Page.find_or_initialize_by(slug: "cfo-quiz")
      page.assign_attributes({
        title: "Is Your Business Ready for a CFO? - Quiz",
        content: cfo_quiz_content,
        meta_description: "Take this quiz to determine if your business needs a bookkeeper, controller, or a strategic CFO (Fractional or Full-Time).",
        meta_keywords: "cfo quiz, fractional cfo, financial leadership, business finance",
        published: true,
        show_in_menu: true,
        position: 100
      })

      if page.save
        puts "CFO Quiz page created/updated successfully!"
      else
        puts "Error creating CFO Quiz page: #{page.errors.full_messages.join(', ')}"
      end
    else
      puts "Page model not defined. Ensure CMS migration has been run."
    end
  end
end

/**
 * TNPSC Professional Web Quiz Logic
 * Powered by Google Sheets (Zero-Cost Scaling)
 */

const CONFIG = {
    // Replace with your Google Sheet CSV Link
    sheetUrl: 'https://docs.google.com/spreadsheets/d/e/2PACX-1vSnufG0r1c65d6DOXTX8ssI0sDhfKYVRehjAKg7LerHdq8ZfIk2hz3FI5cQNdehsAVfqf7Yr6XLrk9E/pub?gid=0&single=true&output=csv',
    yesterdayQuizCount: 20,
    istOffset: 5.5 * 60 * 60 * 1000,

    // ADSENSE CONFIGURATION
    adsense: {
        publisherId: 'ca-pub-9952621231526514', // உங்கள் Publisher ID இங்கே இணைக்கப்பட்டுள்ளது
        bannerSlot: '1111111111',           // ஹோம் பேஜ் விளம்பர ID (தேவைப்பட்டால் மாற்றவும்)
        inlineSlot: '2222222222',           // கேள்விக்கு இடையில் வரும் விளம்பர ID
        resultSlot: '3333333333'            // ரிசல்ட் பேஜ் விளம்பர ID
    }
};

let allQuizzes = [];
let currentQuiz = null;
let currentQuestionIndex = 0;
let score = 0;

// Initialize App
document.addEventListener('DOMContentLoaded', () => {
    initApp();
});

async function initApp() {
    showLoading(true);
    try {
        if (!CONFIG.sheetUrl) {
            showError("Please configure the Google Sheet URL in quiz.js");
            return;
        }
        await fetchQuizData();
        renderHome();
    } catch (error) {
        showError("Failed to load quiz data. Check console for details.");
        console.error("DEBUG INFO:", error);
    } finally {
        showLoading(false);
    }
}

async function fetchQuizData() {
    // Add timestamp to URL to prevent browser caching
    const response = await fetch(`${CONFIG.sheetUrl}${CONFIG.sheetUrl.includes('?') ? '&' : '?'}t=${Date.now()}`);
    const csvData = await response.text();
    allQuizzes = parseCSV(csvData);

    const now = new Date(new Date().getTime() + CONFIG.istOffset);
    const todayStr = now.toISOString().split('T')[0];

    // Group by date
    const grouped = {};
    allQuizzes.forEach(q => {
        if (q.date <= todayStr) {
            if (!grouped[q.date]) grouped[q.date] = [];
            grouped[q.date].push(q);
        }
    });

    // Convert to sorted array (Latest first)
    allQuizzes = Object.keys(grouped).map(date => ({
        date: date,
        questions: grouped[date]
    }))
    .sort((a, b) => b.date.localeCompare(a.date));
}

function parseCSV(csv) {
    const lines = csv.split('\n');
    const result = [];
    if (lines.length === 0) return result;

    const headers = lines[0].split(',').map(h => h.trim().replace(/"/g, ''));

    for (let i = 1; i < lines.length; i++) {
        if (!lines[i].trim()) continue;
        const currentLine = lines[i].split(/,(?=(?:(?:[^"]*"){2})*[^"]*$)/);
        const obj = {};
        headers.forEach((header, index) => {
            let val = currentLine[index] ? currentLine[index].trim().replace(/"/g, '') : '';
            obj[header] = val;
        });
        result.push(obj);
    }
    return result;
}

function getAdHtml(slotId) {
    if (!CONFIG.adsense.publisherId || CONFIG.adsense.publisherId.includes('XXXXX')) {
        return '<div class="ad-label">Advertisement Slot</div>';
    }
    return `
        <ins class="adsbygoogle"
             style="display:block"
             data-ad-client="${CONFIG.adsense.publisherId}"
             data-ad-slot="${slotId}"
             data-ad-format="auto"
             data-full-width-responsive="true"></ins>
        <script>
             (adsbygoogle = window.adsbygoogle || []).push({});
        </script>
    `;
}

function renderHome() {
    // Reset state when returning home
    currentQuiz = null;
    currentQuestionIndex = 0;
    score = 0;

    const container = document.getElementById('main-content');
    if (allQuizzes.length === 0) {
        container.innerHTML = '<div class="info-msg">No quizzes available yet. Check back tomorrow!</div>';
        return;
    }

    const latestQuiz = allQuizzes[0];

    let html = `
        <div class="app-promo-card">
            <div class="promo-content">
                <img src="logo.png" alt="App Logo" style="width: 50px ; height: 50px ; object-fit: contain; border-radius: 6px; padding: 3px;">
                <div class="promo-text">
                    <h5>TNPSC Master: Group 1, 2, 4 --> App Link</h5>
                </div>
            </div>
            <a href="https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book" target="_blank" class="download-btn">Download</a>
        </div>

        <div class="featured-section">
            <h2 class="section-title">Today's Featured Quiz</h2>
            <div class="quiz-card featured" onclick="startQuiz('${latestQuiz.date}')">
                <div class="card-info">
                    <span class="date">${formatDate(latestQuiz.date)}</span>
                    <span class="q-count">${latestQuiz.questions.length} Questions</span>
                </div>
                <button class="start-btn">Start Quiz</button>
            </div>
        </div>

        <div class="ad-slot banner-ad">
            ${getAdHtml(CONFIG.adsense.bannerSlot)}
        </div>

        <div class="history-section">
            <h2 class="section-title">Pick a Date to Play</h2>
            <div class="history-list">
                ${allQuizzes.map(q => `
                    <div class="history-item ${q.date === latestQuiz.date ? 'active' : ''}" onclick="startQuiz('${q.date}')">
                        <div style="display: flex; align-items: center; gap: 10px;">
                            <span class="date">${formatDate(q.date)}</span>
                            <span class="q-tag">${q.date === latestQuiz.date ? 'New' : 'Quiz'}</span>
                        </div>
                        <span class="arrow">Play →</span>
                    </div>
                `).join('')}
            </div>
        </div>
    `;
    container.innerHTML = html;
}

function startQuiz(date) {
    const quiz = allQuizzes.find(q => q.date === date);
    if (!quiz) return;

    // Shuffle questions every time quiz starts
    currentQuiz = {
        ...quiz,
        questions: shuffleArray([...quiz.questions])
    };

    currentQuestionIndex = 0;
    score = 0;
    renderQuestion();
}

function shuffleArray(array) {
    for (let i = array.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [array[i], array[j]] = [array[j], array[i]];
    }
    return array;
}

function renderQuestion() {
    const question = currentQuiz.questions[currentQuestionIndex];
    const container = document.getElementById('main-content');

    container.innerHTML = `
        <div class="quiz-container">
            <div class="progress-bar">
                <div class="progress" style="width: ${((currentQuestionIndex + 1) / currentQuiz.questions.length) * 100}%"></div>
            </div>
            <div class="quiz-header">
                <button class="back-mini-btn" onclick="renderHome()">← Back</button>
                <span class="q-number">Question ${currentQuestionIndex + 1} of ${currentQuiz.questions.length}</span>
                <span class="score-display">Score: ${score}</span>
            </div>

            <div class="question-card">
                <p class="question-text">${question.question}</p>
                <div class="options-grid">
                    <button class="option-btn" onclick="checkAnswer(0)">${question.optionA}</button>
                    <button class="option-btn" onclick="checkAnswer(1)">${question.optionB}</button>
                    <button class="option-btn" onclick="checkAnswer(2)">${question.optionC}</button>
                    <button class="option-btn" onclick="checkAnswer(3)">${question.optionD}</button>
                </div>
            </div>

            <div class="ad-slot inline-ad">
                ${getAdHtml(CONFIG.adsense.inlineSlot)}
            </div>
        </div>
    `;
}

function checkAnswer(selectedIndex) {
    const question = currentQuiz.questions[currentQuestionIndex];
    const buttons = document.querySelectorAll('.option-btn');
    const correctIndex = parseInt(question.answer);

    buttons.forEach((btn, idx) => {
        btn.disabled = true;
        if (idx === correctIndex) {
            btn.classList.add('correct');
        } else if (idx === selectedIndex) {
            btn.classList.add('wrong');
        }
    });

    if (selectedIndex === correctIndex) {
        score++;
    }

    setTimeout(() => {
        if (currentQuiz) nextQuestion(); // Safety check if user backed out
    }, 1500);
}

function nextQuestion() {
    currentQuestionIndex++;
    if (currentQuestionIndex < currentQuiz.questions.length) {
        renderQuestion();
    } else {
        renderResults();
    }
}

function renderResults() {
    const container = document.getElementById('main-content');
    const percentage = Math.round((score / currentQuiz.questions.length) * 100);

    container.innerHTML = `
        <div class="result-card">
            <h2 class="result-title">Quiz Completed!</h2>
            <div class="score-circle">
                <span class="score-num">${score}/${currentQuiz.questions.length}</span>
                <span class="score-percent">${percentage}%</span>
            </div>

            <div class="ad-slot large-ad">
                ${getAdHtml(CONFIG.adsense.resultSlot)}
            </div>

            <div class="action-buttons">
                <button class="share-btn" onclick="shareResult()">Share Result on WhatsApp</button>
                <button class="home-btn" onclick="renderHome()">Back to Home</button>
            </div>
        </div>
    `;
}

function shareResult() {
    const text = `📊 *TNPSC Daily Challenge Result* 📊\n\nI scored *${score}/${currentQuiz.questions.length}* in today's Daily Quiz!\n\nTry it yourself: ${window.location.href}`;
    window.open(`https://api.whatsapp.com/send?text=${encodeURIComponent(text)}`);
}

function formatDate(dateStr) {
    const options = { year: 'numeric', month: 'long', day: 'numeric' };
    return new Date(dateStr).toLocaleDateString('en-US', options);
}

function showLoading(show) {
    document.getElementById('loader').style.display = show ? 'flex' : 'none';
}

function showError(msg) {
    document.getElementById('main-content').innerHTML = `<div class="error-msg">${msg}</div>`;
}

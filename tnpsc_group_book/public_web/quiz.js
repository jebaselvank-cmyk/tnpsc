/**
 * TNPSC Professional Web Quiz Logic
 * Powered by Google Sheets (Zero-Cost Scaling)
 */

const CONFIG = {
    // Replace with your Google Sheet CSV Link (File -> Share -> Publish to Web -> CSV)
    // Or use the gviz/tq format: https://docs.google.com/spreadsheets/d/ID/gviz/tq?tqx=out:csv
    sheetUrl: 'https://docs.google.com/spreadsheets/d/e/2PACX-1vSnufG0r1c65d6DOXTX8ssI0sDhfKYVRehjAKg7LerHdq8ZfIk2hz3FI5cQNdehsAVfqf7Yr6XLrk9E/pub?gid=0&single=true&output=csv',
    yesterdayQuizCount: 20,
    istOffset: 5.5 * 60 * 60 * 1000
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
    // Add timestamp to URL to prevent browser caching (?t=...)
    const response = await fetch(`${CONFIG.sheetUrl}${CONFIG.sheetUrl.includes('?') ? '&' : '?'}t=${Date.now()}`);
    const csvData = await response.text();
    allQuizzes = parseCSV(csvData);

    // Filter by date (Only Yesterday and Older)
    const now = new Date(new Date().getTime() + CONFIG.istOffset);
    const todayStr = now.toISOString().split('T')[0];

    // Group by date
    const grouped = {};
    allQuizzes.forEach(q => {
        // Change < to <= to show today's quiz as well
        if (q.date <= todayStr) {
            if (!grouped[q.date]) grouped[q.date] = [];
            grouped[q.date].push(q);
        }
    });

    // Convert to sorted array (Show EVERYTHING in the sheet)
    allQuizzes = Object.keys(grouped).map(date => ({
        date: date,
        questions: grouped[date]
    }))
    .sort((a, b) => b.date.localeCompare(a.date));
    // .slice(0, 60); // Limit removed for infinite history
}

function parseCSV(csv) {
    const lines = csv.split('\n');
    const result = [];
    const headers = lines[0].split(',').map(h => h.trim().replace(/"/g, ''));

    for (let i = 1; i < lines.length; i++) {
        if (!lines[i]) continue;
        const currentLine = lines[i].split(/,(?=(?:(?:[^"]*"){2})*[^"]*$)/); // Handle commas inside quotes
        const obj = {};
        headers.forEach((header, index) => {
            let val = currentLine[index] ? currentLine[index].trim().replace(/"/g, '') : '';
            obj[header] = val;
        });
        result.push(obj);
    }
    return result;
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

    // Default to the latest quiz (Yesterday's)
    const latestQuiz = allQuizzes[0];
    const history = allQuizzes.slice(1);

    let html = `
        <div class="app-promo-card" style="max-height: 65px; overflow: hidden; display: flex; align-items: center; justify-content: space-between; background: #0d47a1; padding: 5px 15px; border-radius: 8px; margin-bottom: 15px;">
            <div class="promo-content" style="display: flex; align-items: center; gap: 10px;">
                <img src="asset/images/logo.png" alt="App Logo" style="width: 50px !important; height: 50px !important; object-fit: contain; border-radius: 4px; background: white;">
                <div class="promo-text">
                    <h3 style="font-size: 0.9rem; margin: 0; color: white;">TNPSC Group Book App</h3>
                </div>
            </div>
            <a href="https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book" target="_blank" class="download-btn" style="background: white; color: #0d47a1; text-decoration: none; padding: 4px 10px; border-radius: 4px; font-weight: 700; font-size: 0.75rem;">Download</a>
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
            <div class="ad-label">Advertisement</div>
        </div>

        <div class="history-section">
            <h2 class="section-title">Pick a Date to Play</h2>
            <div class="history-list">
                ${allQuizzes.map(q => `
                    <div class="history-item ${q.date === latestQuiz.date ? 'active' : ''}" onclick="startQuiz('${q.date}')">
                        <span class="date">${formatDate(q.date)}</span>
                        <span class="q-tag">${q.date === latestQuiz.date ? 'New' : 'Quiz'}</span>
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
                <!-- AdSense Inline Placeholder -->
                <div class="ad-label">Advertisement</div>
            </div>
        </div>
    `;
}

function checkAnswer(selectedIndex) {
    const question = currentQuiz.questions[currentQuestionIndex];
    const buttons = document.querySelectorAll('.option-btn');
    const correctIndex = parseAnswer(question.answer);

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
        nextQuestion();
    }, 1500);
}

function parseAnswer(ans) {
    ans = ans.toUpperCase();
    if (ans === 'A' || ans === '0') return 0;
    if (ans === 'B' || ans === '1') return 1;
    if (ans === 'C' || ans === '2') return 2;
    if (ans === 'D' || ans === '3') return 3;
    return -1;
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
                <!-- AdSense Large Rectangular Placeholder -->
                <div class="ad-label">Advertisement</div>
            </div>

            <div class="action-buttons">
                <button class="share-btn" onclick="shareResult()">Share Result on WhatsApp</button>
                <button class="home-btn" onclick="location.reload()">Back to Home</button>
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

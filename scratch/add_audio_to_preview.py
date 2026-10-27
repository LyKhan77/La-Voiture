with open('temp/car_spotlight_preview.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Add audio element
audio_tag = '<audio id="podiumBgm" src="../assets/audio/music/podium_rock_anthem.mp3" loop></audio>'
content = content.replace('<!-- CAR SPOTLIGHT & LIGHTING RIG LAYER', audio_tag + '\n    <!-- CAR SPOTLIGHT & LIGHTING RIG LAYER')

# Add toolbar button
btn_tag = '''<button class="tool-btn" id="btnMusic" onclick="toggleMusic()">
            <span class="key-badge">P</span> Play Anthem (Rock)
        </button>
        <button class="tool-btn"'''
content = content.replace('<button class="tool-btn" onclick="alert(\'Tekan ESC', btn_tag + ' onclick="alert(\'Tekan ESC')

# Add JS handler
music_js = '''
let musicPlaying = false;
function toggleMusic() {
    const audio = document.getElementById('podiumBgm');
    const btn = document.getElementById('btnMusic');
    if (!musicPlaying) {
        audio.play().then(() => {
            musicPlaying = true;
            btn.classList.add('active');
            btn.innerHTML = '<span class="key-badge">P</span> Pause Anthem';
        }).catch(e => console.log('Autoplay prevented:', e));
    } else {
        audio.pause();
        musicPlaying = false;
        btn.classList.remove('active');
        btn.innerHTML = '<span class="key-badge">P</span> Play Anthem (Rock)';
    }
}
'''
content = content.replace('window.addEventListener(\'keydown\'', music_js + '\nwindow.addEventListener(\'keydown\'')
content = content.replace('} else if (e.key.toLowerCase() === \'m\') {', '''} else if (e.key.toLowerCase() === 'p') {
        toggleMusic();
    } else if (e.key.toLowerCase() === 'm') {''')

with open('temp/car_spotlight_preview.html', 'w', encoding='utf-8') as f:
    f.write(content)
print('Updated HTML preview with Audio Anthem button!')

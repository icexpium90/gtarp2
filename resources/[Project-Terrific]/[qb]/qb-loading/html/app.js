const { ref } = Vue

// Customize language for dialog menus and carousels here

const load = Vue.createApp({
  setup () {
    return {
      CarouselText1: 'Bienvenue sur LUSO RP',
      CarouselSubText1: 'Roleplay serieux et convivial : respectez les regles et les autres joueurs.',
      CarouselText2: 'Rejoignez notre Discord',
      CarouselSubText2: 'discord.gg/MuFbeK87B4 : annonces, candidatures, support et signalements.',
      CarouselText3: 'Metiers, entreprises, gangs et immobilier',
      CarouselSubText3: 'Police, EMS, mecaniciens, agence immobiliere, LS Customs, concessions et bien plus.',
      CarouselText4: 'Besoin d\'aide en jeu ?',
      CarouselSubText4: 'Utilisez /report ou contactez un membre du staff sur Discord.',

      DownloadTitle: 'Chargement de LUSO RP',
      DownloadDesc: "Patientez pendant le telechargement des ressources du serveur (cartes, vehicules, scripts).\n\nLa premiere connexion peut prendre quelques minutes. Une fois termine, vous arriverez directement en ville : ne fermez pas le jeu.",

      SettingsTitle: 'Parametres',
      AudioTrackDesc1: 'Desactive : la musique en cours s\'arrete.',
      AutoPlayDesc2: 'Desactive : les images ne defilent plus.',
      PlayVideoDesc3: 'Desactive : la video reste en pause.',

      KeybindTitle: 'Touches par defaut',
      Keybind1: 'Inventaire',
      Keybind2: 'Portee de la voix',
      Keybind3: 'Telephone',
      Keybind4: 'Ceinture',
      Keybind5: 'Menu d\'interaction',
      Keybind6: 'Menu radial',
      Keybind7: 'Menu du HUD',
      Keybind8: 'Parler a la radio',
      Keybind9: 'Liste des joueurs',
      Keybind10: 'Verrouiller le vehicule',
      Keybind11: 'Moteur',
      Keybind12: 'Pointer du doigt',
      Keybind13: 'Raccourcis',
      Keybind14: 'Mains en l\'air',
      Keybind15: 'Objets rapides',
      Keybind16: 'Regulateur de vitesse',

      firstap: ref(true),
      secondap: ref(true),
      thirdap: ref(true),
      firstslide: ref(1),
      secondslide: ref('1'),
      thirdslide: ref('5'),
      audioplay: ref(true),
      playvideo: ref(true),
      download: ref(true),
      settings: ref(false),
    }
  }
})

load.use(Quasar, { config: {} })
load.mount('#loading-main')

var audio = document.getElementById("audio");
audio.volume = 0.05;

function audiotoggle() {
    var audio = document.getElementById("audio");
    if (audio.paused) {
        audio.play();
    } else {
        audio.pause();
    }
}

function videotoggle() {
    var video = document.getElementById("video");
    if (video.paused) {
        video.play();
    } else {
        video.pause();
    }
}

let count = 0;
let thisCount = 0;

const handlers = {
    startInitFunctionOrder(data) {
        count = data.count;
    },

    initFunctionInvoking(data) {
        document.querySelector(".thingy").style.left = "0%";
        document.querySelector(".thingy").style.width = (data.idx / count) * 100 + "%";
    },

    startDataFileEntries(data) {
        count = data.count;
    },

    performMapLoadFunction(data) {
        ++thisCount;

        document.querySelector(".thingy").style.left = "0%";
        document.querySelector(".thingy").style.width = (thisCount / count) * 100 + "%";
    },
};

window.addEventListener("message", function (e) {
    (handlers[e.data.eventName] || function () {})(e.data);
});

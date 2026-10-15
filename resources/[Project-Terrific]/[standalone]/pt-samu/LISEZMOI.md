# pt-samu : SAMU automatique

- Un joueur a terre appelle le **15** automatiquement au bout de 20 s (ou tout de suite avec **G**).
- **Des SAMU / pompiers sont de garde** : ils recoivent l'alerte. Si personne n'arrive en 4 minutes, un VSAV de reserve
  (IA) est engage quand meme.
- **Personne de garde** : un VSAV pilote par l'IA (sirene, gyrophares) part de la route la plus proche, le medecin du
  SMUR descend, fait un massage cardiaque et vous reanime sur place.
- Intervention : $750 (liquide puis banque), versee sur le compte de l'entreprise SAMU. Sans argent : prise en charge
  par la Securite sociale (gratuit). Tout se regle dans `config.lua`.
- Securite : la reanimation et le paiement sont decides par le serveur (impossible de se reanimer en trichant).
- Remplace `hh_aidoc` (deplace dans `[desactive]`).

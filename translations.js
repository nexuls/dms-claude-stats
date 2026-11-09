.pragma library

var strings = {
    "Claude Code Usage":
        { fr: "Utilisation Claude Code", es: "Uso de Claude Code" },
    "Subscription":
        { fr: "Abonnement", es: "Suscripción" },
    "Resetting...":
        { fr: "Réinitialisation...", es: "Restableciendo..." },
    "sessions":
        { fr: "sessions", es: "sesiones" },
    "msgs":
        { fr: "messages", es: "mensajes" },
    "Daily Activity":
        { fr: "Activité quotidienne", es: "Actividad diaria" },
    "Today":
        { fr: "Aujourd'hui", es: "Hoy" },
    "Week":
        { fr: "Semaine", es: "Semana" },
    "Month":
        { fr: "Mois", es: "Mes" },
    "Models This Week":
        { fr: "Modèles cette semaine", es: "Modelos esta semana" },
    "Since":
        { fr: "Depuis", es: "Desde" },
    "Max":
        { fr: "Max", es: "Max" },
    "Pro":
        { fr: "Pro", es: "Pro" },
    "Free":
        { fr: "Gratuit", es: "Gratis" },
    "Team":
        { fr: "Équipe", es: "Equipo" },
    "Enterprise":
        { fr: "Entreprise", es: "Empresa" },
    // Settings
    "Monitor your Claude Code subscription usage. Rate limits and subscription tier are detected automatically via the Anthropic API.":
        {
            fr: "Surveillez l'utilisation de votre abonnement Claude Code. Les limites d'utilisation et le type d'abonnement sont détectés automatiquement via l'API Anthropic.",
            es: "Supervisa el uso de tu suscripción a Claude Code. Los límites de uso y el tipo de suscripción se detectan automáticamente mediante la API de Anthropic."
        },
    "Refresh Interval":
        { fr: "Intervalle de rafraîchissement", es: "Intervalo de actualización" },
    "How often to fetch usage data (minutes)":
        { fr: "Fréquence de mise à jour des données (minutes)", es: "Frecuencia de actualización de los datos (minutos)" },
    "All":
        { fr: "Tout", es: "Todos" },
    // Pacing
    "over pace":
        { fr: "au-dessus du rythme", es: "por encima del ritmo" },
    "under pace":
        { fr: "en dessous du rythme", es: "por debajo del ritmo" },
    "On pace":
        { fr: "Dans les temps", es: "Al ritmo previsto" },
    "Over quota":
        { fr: "Quota dépassé", es: "Cuota superada" },
    "Show pacing":
        { fr: "Afficher le rythme", es: "Mostrar el ritmo de consumo" },
    "Show whether usage is ahead of or behind the time window":
        {
            fr: "Indique si l'utilisation est en avance ou en retard sur la fenêtre de temps",
            es: "Indica si el consumo está adelantado o retrasado respecto a la ventana de tiempo"
        },
    // Layout
    "5 hours":
        { fr: "5 heures", es: "5 horas" },
    "7 days":
        { fr: "7 jours", es: "7 días" },
    "Bar style":
        { fr: "Style de la barre", es: "Estilo de la barra" },
    "What the bar widget shows":
        { fr: "Ce qu'affiche le widget de la barre", es: "Lo que muestra el widget de la barra" },
    "Ring and percentage":
        { fr: "Anneau et pourcentage", es: "Anillo y porcentaje" },
    "Ring only":
        { fr: "Anneau seul", es: "Solo anillo" },
    "5-hour and 7-day rings":
        { fr: "Anneaux 5 heures et 7 jours", es: "Anillos de 5 horas y 7 días" },
    "Percentages only":
        { fr: "Pourcentages seuls", es: "Solo porcentajes" },
    "Popout layout":
        { fr: "Disposition du panneau", es: "Diseño del panel" },
    "Detailed adds reset times, projections, daily averages, per-day totals and all-time stats":
        {
            fr: "Le mode détaillé ajoute les heures de réinitialisation, les projections, les moyennes quotidiennes, les totaux par jour et les statistiques globales",
            es: "El modo detallado añade las horas de restablecimiento, las proyecciones, los promedios diarios, los totales por día y las estadísticas totales"
        },
    "Resets":
        { fr: "Réinit.", es: "Se restablece" },
    "Projected":
        { fr: "Projection", es: "Proyección" },
    "of week":
        { fr: "de la semaine", es: "de la semana" },
    "/day":
        { fr: "/jour", es: "/día" },
    "Compact":
        { fr: "Compact", es: "Compacto" },
    "Detailed":
        { fr: "Détaillé", es: "Detallado" },
    // Activity
    "Show Claude activity":
        { fr: "Afficher l'activité de Claude", es: "Mostrar la actividad de Claude" },
    "Animate the bar icon while Claude works and flag when it needs your input. Requires the claude-activity-hook in your Claude Code settings, see the README.":
        {
            fr: "Anime l'icône de la barre pendant que Claude travaille et signale quand il attend votre réponse. Nécessite claude-activity-hook dans vos réglages Claude Code, voir le README.",
            es: "Anima el icono de la barra mientras Claude trabaja y avisa cuando necesita tu respuesta. Requiere claude-activity-hook en tu configuración de Claude Code, consulta el README."
        },
    "Needs your input":
        { fr: "Attend votre réponse", es: "Necesita tu respuesta" },
    "Working":
        { fr: "En cours", es: "Trabajando" },
    "Done":
        { fr: "Terminé", es: "Terminado" },
    "Refresh":
        { fr: "Actualiser", es: "Actualizar" },
    "Settings":
        { fr: "Paramètres", es: "Ajustes" },
    "Custom Profiles":
        { fr: "Profils personnalisés", es: "Perfiles personalizados" },
    "Name":
        { fr: "Nom", es: "Nombre" },
    "Config directory":
        { fr: "Dossier de configuration", es: "Directorio de configuración" },
    "Track extra Claude config directories. Point at a CLAUDE_CONFIG_DIR (the folder containing projects/). ~/.claude, Claude Code Switcher and claude-code-profiles are detected automatically.":
        {
            fr: "Suivez d'autres dossiers de configuration Claude. Indiquez un CLAUDE_CONFIG_DIR (le dossier contenant projects/). ~/.claude, Claude Code Switcher et claude-code-profiles sont détectés automatiquement.",
            es: "Haz seguimiento de otros directorios de configuración de Claude. Indica un CLAUDE_CONFIG_DIR (la carpeta que contiene projects/). ~/.claude, Claude Code Switcher y claude-code-profiles se detectan automáticamente."
        },
    "Add":
        { fr: "Ajouter", es: "Añadir" },
    "Remove":
        { fr: "Supprimer", es: "Eliminar" },
    "No items added yet":
        { fr: "Aucun élément ajouté pour le moment", es: "Todavía no se ha añadido ningún elemento" },
    "No Claude Code CLI login found. Run `claude /login` to see rate limits.":
        { fr: "Aucune connexion Claude Code CLI trouvée. Exécutez `claude /login` pour voir les limites d'utilisation.", es: "No se encontró ningún inicio de sesión de Claude Code CLI. Ejecuta `claude /login` para ver los límites de uso." },
    "Claude Code login expired. Run `claude` to refresh it.":
        { fr: "La connexion à Claude Code a expiré. Exécutez `claude` pour la renouveler.", es: "El inicio de sesión de Claude Code ha caducado. Ejecuta `claude` para renovarlo." },
    "The usage API is rate limiting requests. Showing the last known values.":
        { fr: "L'API d'utilisation limite les requêtes. Dernières valeurs connues affichées.", es: "La API de uso está limitando las solicitudes. Se muestran los últimos valores conocidos." },
    "Could not reach the usage API. Showing the last known values.":
        { fr: "Impossible de joindre l'API d'utilisation. Dernières valeurs connues affichées.", es: "No se pudo contactar con la API de uso. Se muestran los últimos valores conocidos." },
}

function tr(key, lang) {
    if (!lang || lang === "en" || !strings[key] || !strings[key][lang])
        return key
    return strings[key][lang]
}

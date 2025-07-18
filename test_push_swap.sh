#!/bin/bash

format_time() {
    local secs=$1
    printf "%02d:%02d" $((secs / 60)) $((secs % 60))
}

# Affiche une barre de progression graphique
print_progress() {

    local current=$1
    local total=$2
    local BAR_WIDTH=100
    local percent=$(( current * 100 / total ))
    local filled=$(( percent * BAR_WIDTH / 100 ))
    local empty=$(( BAR_WIDTH - filled ))

    # BAR
    local bar_filled=$(printf "%${filled}s" "")
    local bar_empty=$(printf "%${empty}s" "")

    # TIME
    local now=$(date +%s)
    local elapsed=$(( now - start_time ))

    if (( percent > 0 )); then
        local estimated_total=$(( elapsed * 100 / percent ))
        local remaining=$(( estimated_total - elapsed ))
    else
        local remaining=0
    fi

    if (( current == total )); then
        printf "\rProgression :\e[30;102m %s \e[0m %s %3d%% (%d/%d) | ⏱️  %s • ⌛ %s" \
        "$bar_filled" "$bar_empty" "$percent" "$current" "$total" "$(format_time $elapsed)" "$(format_time $remaining)"
        printf "\n"
    else
        printf "\rProgression :\e[30;103m %s \e[0m %s %3d%% (%d/%d) | ⏱️  %s • ⌛ %s" \
        "$bar_filled" "$bar_empty" "$percent" "$current" "$total" "$(format_time $elapsed)" "$(format_time $remaining)"
    fi
}

# Demande à l'utilisateur le nombre de tests et la taille des listes
read -p "Nombre de tests : " nb_tests
read -p "Taille de la liste : " list_size
read -p "Nombre d'opérations visé : " target

# Vérifie que push_swap et checker_linux existent
if [[ ! -x ./push_swap ]]; then
    printf "\n\e[91m%s\e[0m" "Erreur : ./push_swap est introuvable ou non exécutable."
    exit 1
fi

if [[ ! -x ./checker_linux ]]; then
    printf "\n\e[91m%s\e[0m" "Erreur : ./checker_linux est introuvable ou non exécutable."
    exit 1
fi

success=0
pass=0
min_op=1000000  # très grand nombre pour initialisation
max_op=0
total_op=0
start_time=$(date +%s)

# Boucle principale de test
for ((i=1; i<=nb_tests; i++)); do


    print_progress $i $nb_tests

    # Génère une permutation aléatoire unique de 0 à list_size - 1
    args=$(shuf -i 0-$(($list_size - 1)) | tr '\n' ' ')

    # Exécute push_swap pour obtenir les instructions
    instructions=$(./push_swap $args)
    op_count=$(echo "$instructions" | wc -l)

    # Vérifie le résultat avec checker_linux
    result=$(echo "$instructions" | ./checker_linux $args)

    if [[ "$result" == "OK" ]]; then
        ((success++))
        total_op=$((total_op + op_count))

        # Mise à jour min/max
        if (( op_count < min_op )); then
            min_op=$op_count
        fi

        if (( op_count > max_op )); then
            max_op=$op_count
        fi

        # Vérifie si on est en dessous de l'objectif
        if (( op_count <= target )); then
            ((pass++))
        fi
    else
        printf "\n\e[91m%s %d : %d  %s \e[0m\n" "Test" "$i" "$result" "Erreur détectée avec la liste :"
        echo "$args"
        exit 1
    fi
done

average_op=$(echo "scale=2; $total_op / $nb_tests" | bc)

# Affiche les résultats
echo ""
echo "------------------------------"
echo "Tests réussis : $success / $nb_tests"
echo "Opérations minimum : $min_op"
echo "Opérations maximum : $max_op"
echo "Opérations moyenne : $average_op"

success_rate=$(echo "scale=2; $success * 100 / $nb_tests" | bc)
pass_rate=$(echo "scale=2; $pass * 100 / $nb_tests" | bc)

echo "Taux de réussite : $success_rate %"
echo "Taux sous objectif ($target opérations) : $pass_rate %"

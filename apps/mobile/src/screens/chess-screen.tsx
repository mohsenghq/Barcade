import React, { useCallback, useEffect, useRef, useState } from "react";
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  Alert,
  ScrollView,
} from "react-native";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import type { RootStackParamList } from "../../App";
import {
  GameState,
  GameStatus,
  SaveController,
  SettingsService,
} from "@starcade/core";

type Props = NativeStackScreenProps<RootStackParamList, "Chess"> & {
  save: SaveController;
  settings: SettingsService;
};

export function ChessScreen({
  route,
  navigation,
  save,
  settings,
}: Props) {
  const { mode } = route.params;
  const [gameState, setGameState] = useState(() => new GameState());
  const [ended, setEnded] = useState(false);
  const [whiteElapsed, setWhiteElapsed] = useState(0);
  const [blackElapsed, setBlackElapsed] = useState(0);

  const gameStateRef = useRef(gameState);
  gameStateRef.current = gameState;

  // Clock ticker
  useEffect(() => {
    if (ended) return;
    const interval = setInterval(() => {
      if (gameStateRef.current.sideToMove === "white") {
        setWhiteElapsed((s) => s + 1);
      } else {
        setBlackElapsed((s) => s + 1);
      }
    }, 1000);
    return () => clearInterval(interval);
  }, [ended]);

  const checkGameEnd = useCallback(
    (gs: GameState) => {
      switch (gs.status) {
        case GameStatus.Checkmate: {
          const winner = gs.sideToMove === "white" ? "black" : "white";
          const subtitle =
            mode === "ai"
              ? winner === "white"
                ? "You won"
                : "AI won"
              : `${winner === "white" ? "White" : "Black"} wins`;
          Alert.alert("Checkmate", subtitle, [
            { text: "Rematch", onPress: handleRematch },
            { text: "New Game", onPress: () => navigation.goBack() },
          ]);
          setEnded(true);
          break;
        }
        case GameStatus.Stalemate:
          Alert.alert("Stalemate", undefined, [
            { text: "Rematch", onPress: handleRematch },
            { text: "New Game", onPress: () => navigation.goBack() },
          ]);
          setEnded(true);
          break;
        case GameStatus.Draw:
          Alert.alert("Draw", gs.drawReason ?? undefined, [
            { text: "Rematch", onPress: handleRematch },
            { text: "New Game", onPress: () => navigation.goBack() },
          ]);
          setEnded(true);
          break;
        default:
          break;
      }
    },
    [mode, navigation],
  );

  const handleUserMove = useCallback(
    (uci: string) => {
      if (ended) return;
      const gs = gameStateRef.current;
      if (!gs.makeMove(uci)) return;
      setGameState(new GameState(gs.fen));
      checkGameEnd(gs);
    },
    [ended, checkGameEnd],
  );

  const handleRematch = useCallback(() => {
    setGameState(new GameState());
    setEnded(false);
    setWhiteElapsed(0);
    setBlackElapsed(0);
  }, []);

  const formatTime = (s: number) => {
    const mm = String(Math.floor(s / 60) % 60).padStart(2, "0");
    const ss = String(s % 60).padStart(2, "0");
    return `${mm}:${ss}`;
  };

  const playerBar = (name: string, side: "white" | "black", active: boolean) => (
    <View style={styles.playerBar}>
      <Text style={[styles.playerName, !active && styles.inactive]}>{name}</Text>
      <Text style={[styles.clock, !active && styles.inactive]}>
        {side === "white" ? formatTime(whiteElapsed) : formatTime(blackElapsed)}
      </Text>
    </View>
  );

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        {playerBar(mode === "ai" ? "AI" : "Black", "black", !ended && gameState.sideToMove === "black")}

        <View style={styles.boardPlaceholder}>
          <Text style={styles.boardText}>
            Chess board{"\n"}
            {gameState.sideToMove} to move{"\n"}
            {gameState.pgnMoves.length} moves played
          </Text>
        </View>

        {playerBar(mode === "ai" ? "You" : "White", "white", !ended && gameState.sideToMove === "white")}

        <ScrollView style={styles.moveList}>
          {gameState.pgnMoves.map((m, i) => (
            <Text key={i} style={styles.moveText}>
              {m}
            </Text>
          ))}
        </ScrollView>

        <View style={styles.controls}>
          <TouchableOpacity
            onPress={handleRematch}
            style={styles.controlBtn}
          >
            <Text style={styles.controlText}>Rematch</Text>
          </TouchableOpacity>
          <TouchableOpacity
            onPress={() => navigation.goBack()}
            style={styles.controlBtn}
          >
            <Text style={styles.controlText}>Back</Text>
          </TouchableOpacity>
        </View>
      </View>
    </SafeAreaView>
  );
}

const COLORS = {
  indigoDeep: "#130E24",
  cosmic: "#F6F3FF",
  cyan: "#29E0E0",
  surface: "rgba(255,255,255,0.08)",
  surfaceStroke: "rgba(255,255,255,0.18)",
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.indigoDeep,
  },
  content: {
    flex: 1,
    padding: 16,
  },
  playerBar: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingVertical: 8,
  },
  playerName: {
    fontSize: 14,
    fontWeight: "700",
    color: COLORS.cosmic,
  },
  inactive: {
    opacity: 0.55,
  },
  clock: {
    fontSize: 14,
    fontWeight: "600",
    fontVariant: ["tabular-nums"],
    color: COLORS.cosmic,
  },
  boardPlaceholder: {
    flex: 1,
    aspectRatio: 1,
    maxHeight: 400,
    alignSelf: "center",
    backgroundColor: COLORS.surface,
    borderWidth: 1,
    borderColor: COLORS.surfaceStroke,
    borderRadius: 12,
    alignItems: "center",
    justifyContent: "center",
  },
  boardText: {
    color: COLORS.cosmic,
    textAlign: "center",
    opacity: 0.5,
  },
  moveList: {
    maxHeight: 104,
    backgroundColor: COLORS.surface,
    borderWidth: 1,
    borderColor: COLORS.surfaceStroke,
    borderRadius: 12,
    padding: 10,
    marginVertical: 8,
  },
  moveText: {
    fontSize: 13,
    color: COLORS.cosmic,
    fontVariant: ["tabular-nums"],
  },
  controls: {
    flexDirection: "row",
    justifyContent: "space-around",
    paddingVertical: 8,
  },
  controlBtn: {
    paddingVertical: 8,
    paddingHorizontal: 16,
  },
  controlText: {
    fontSize: 14,
    fontWeight: "700",
    color: `${COLORS.cosmic}90`,
  },
});

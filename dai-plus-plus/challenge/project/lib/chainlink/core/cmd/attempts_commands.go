package cmd

import "github.com/urfave/cli"

func initAttemptsSubCmds(s *Shell) []cli.Command {
	return []cli.Command{
		{
			Name:   "list",
			Usage:  "List the Transaction Attempts in descending order",
			Action: s.IndexTxAttempts,
			Flags: []cli.Flag{
				cli.IntFlag{
					Name:  "page",
					Usage: "page of results to display",
				},
			},
		},
	}
}

// IndexTxAttempts returns the list of transactions in descending order,
// taking an optional page parameter
func (s *Shell) IndexTxAttempts(c *cli.Context) error {
	return s.getPage("/v2/tx_attempts/evm", c.Int("page"), &EthTxPresenters{})
}

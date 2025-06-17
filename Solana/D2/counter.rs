use anchor_lang::prelude::*;

declare_id!("Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkgzsCwBbmHzE"); // 替换为你的 program id

#[program]
pub mod counter {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        let counter = &mut ctx.accounts.counter;
        counter.count = 0;
        Ok(())
    }

    pub fn increment(ctx: Context<Increment>) -> Result<()> {
        let counter = &mut ctx.accounts.counter;
        counter.count += 1;
        Ok(())
    }
}

#[derive(Accounts)]
#[instruction()]
pub struct Initialize<'info> {
    #[account(
        init,
        payer = user,
        space = 8 + 8, // 8 bytes for discriminator, 8 bytes for count
        seeds = [b"counter", user.key().as_ref()],
        bump
    )]
    pub counter: Account<'info, CounterAccount>,

    #[account(mut)]
    pub user: Signer<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Increment<'info> {
    #[account(
        mut,
        seeds = [b"counter", user.key().as_ref()],
        bump
    )]
    pub counter: Account<'info, CounterAccount>,

    pub user: Signer<'info>,
}

#[account]
pub struct CounterAccount {
    pub count: u64,
}